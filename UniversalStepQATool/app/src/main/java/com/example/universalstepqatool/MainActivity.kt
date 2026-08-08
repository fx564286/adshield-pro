package com.example.universalstepqatool

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale
import kotlin.math.sqrt

class MainActivity : AppCompatActivity(), SensorEventListener {

    companion object {
        private const val TAG = "UniversalStepQATool"
        private const val FALLBACK_THRESHOLD = 1.35
        private const val FALLBACK_REFRACTORY_NS = 280_000_000L
        private const val UI_REFRESH_MS = 250L
        private const val AUTO_QA_INTERVAL_MS = 600L
        private const val VIRTUAL_SHAKE_INTERVAL_MS = 120L
        private const val PREFS = "qa_state"
        private const val PREF_LOCAL_STEPS = "local_steps"
    }

    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var sensorListening = false
    private var registeredStepCounter = false
    private var registeredStepDetector = false
    private var registeredAccelerometer = false

    private lateinit var statusView: TextView
    private lateinit var platformInfoView: TextView
    private lateinit var sensorInfoView: TextView
    private lateinit var localCountView: TextView
    private lateinit var logView: TextView
    private lateinit var sensorButton: Button
    private lateinit var autoButton: Button
    private lateinit var virtualShakeButton: Button

    private var latestStepCounter: Float? = null
    private var detectorEvents = 0
    private var fallbackAccelSteps = 0
    private var localQaSteps = 0
    private var latestAccelMagnitude = 0.0
    private var filteredDynamic = 0.0
    private var gravityEstimate = 9.81
    private var lastFallbackStepNs = 0L
    private var lastUiRefreshMs = 0L

    // Internal-only synthetic acceleration state. These samples never enter Android SensorManager.
    private var virtualShakeRunning = false
    private var virtualShakePhase = 0
    private var virtualAccelMagnitude = 9.81
    private var virtualGravityEstimate = 9.81
    private var virtualFilteredDynamic = 0.0
    private var virtualLastStepNs = 0L
    private var virtualDetectedSteps = 0

    private val mainHandler = Handler(Looper.getMainLooper())

    private var autoQaRunning = false
    private val autoQaTick = object : Runnable {
        override fun run() {
            if (!autoQaRunning) return
            localQaSteps += 1
            persistLocalCount()
            renderLocalCount()
            mainHandler.postDelayed(this, AUTO_QA_INTERVAL_MS)
        }
    }

    private val virtualShakeTick = object : Runnable {
        override fun run() {
            if (!virtualShakeRunning) return

            // One walking-like pulse approximately every 600 ms (~100/min).
            // Values are app-internal test samples, not hardware sensor injection.
            val magnitude = when (virtualShakePhase) {
                0 -> 9.81
                1 -> 14.80
                2 -> 8.70
                3 -> 11.20
                else -> 9.81
            }
            processVirtualAccelerationSample(magnitude, SystemClock.elapsedRealtimeNanos())
            virtualShakePhase = (virtualShakePhase + 1) % 5
            renderSensorValues(force = false)
            mainHandler.postDelayed(this, VIRTUAL_SHAKE_INTERVAL_MS)
        }
    }

    private val activityPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        safeUi("활동 인식 권한 결과") {
            if (granted) {
                statusView.text = "상태: 활동 인식 권한 승인"
                log("[권한] ACTIVITY_RECOGNITION 승인")
                startSensorsNow(includeStepSensors = true)
            } else {
                statusView.text = "상태: 활동 인식 권한 거부 / 가속도계 폴백 실행"
                log("[권한] ACTIVITY_RECOGNITION 거부")
                log("[폴백] 권한이 없어도 가속도계 진단은 계속 시작합니다.")
                startSensorsNow(includeStepSensors = false)
            }
            renderPlatformInfo()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusView = findViewById(R.id.status)
        platformInfoView = findViewById(R.id.platformInfo)
        sensorInfoView = findViewById(R.id.sensorInfo)
        localCountView = findViewById(R.id.localCountView)
        logView = findViewById(R.id.logView)
        sensorButton = findViewById(R.id.sensorButton)
        autoButton = findViewById(R.id.autoButton)
        virtualShakeButton = findViewById(R.id.virtualShakeButton)

        localQaSteps = getSharedPreferences(PREFS, MODE_PRIVATE).getInt(PREF_LOCAL_STEPS, 0)

        safeUi("센서 초기화") {
            sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
            stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            stepDetectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
            accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        }

        bindButtons()
        renderPlatformInfo()
        renderLocalCount()
        renderSensorValues(force = true)

        log("앱 시작: v8 덮어쓰기/가상가속도 QA판")
        log("패키지: com.example.universalstepqatool")
        log("활동 인식 권한이 없어도 가속도계 폴백이 차단되지 않습니다.")
        log("가상 흔들림은 앱 내부 필터에만 합성 샘플을 공급합니다.")
    }

    override fun onResume() {
        super.onResume()
        if (::platformInfoView.isInitialized) renderPlatformInfo()
    }

    private fun bindButtons() {
        findViewById<Button>(R.id.selfTestButton).setOnClickListener {
            safeUi("앱 자체 점검") { runSelfTest() }
        }
        sensorButton.setOnClickListener {
            safeUi("센서 시작/중지") {
                if (sensorListening) stopSensors() else requestAndStartSensors()
            }
        }
        virtualShakeButton.setOnClickListener {
            safeUi("가상 흔들림 QA") {
                if (virtualShakeRunning) stopVirtualShakeQa() else startVirtualShakeQa()
            }
        }
        autoButton.setOnClickListener {
            safeUi("자동 QA 카운터") {
                if (autoQaRunning) stopAutoQa() else startAutoQa()
            }
        }
        findViewById<Button>(R.id.add100Button).setOnClickListener {
            safeUi("QA +100") { addLocalSteps(100) }
        }
        findViewById<Button>(R.id.add1000Button).setOnClickListener {
            safeUi("QA +1000") { addLocalSteps(1000) }
        }
        findViewById<Button>(R.id.resetButton).setOnClickListener {
            safeUi("QA 초기화") {
                localQaSteps = 0
                detectorEvents = 0
                fallbackAccelSteps = 0
                virtualDetectedSteps = 0
                virtualAccelMagnitude = 9.81
                virtualGravityEstimate = 9.81
                virtualFilteredDynamic = 0.0
                virtualLastStepNs = 0L
                persistLocalCount()
                renderLocalCount()
                renderSensorValues(force = true)
                log("[QA] 앱 내부 테스트 값 초기화")
            }
        }
        findViewById<Button>(R.id.healthConnectButton).setOnClickListener {
            safeUi("Health Connect 내부 화면") {
                startActivity(Intent(this, HealthConnectActivity::class.java))
                log("[이동] 읽기 전용 Health Connect 진단 화면 열기")
            }
        }
    }

    private fun addLocalSteps(count: Int) {
        localQaSteps += count
        persistLocalCount()
        renderLocalCount()
        log("[QA] 로컬 테스트 카운트 +$count → $localQaSteps")
    }

    private fun startVirtualShakeQa() {
        if (virtualShakeRunning) return
        virtualShakeRunning = true
        virtualShakePhase = 0
        virtualGravityEstimate = 9.81
        virtualFilteredDynamic = 0.0
        virtualLastStepNs = 0L
        virtualShakeButton.text = "가상 흔들림 QA 중지"
        statusView.text = "상태: 가상 가속도 QA 실행 중"
        log("[가상센서] 시작: 앱 내부 합성 가속도 샘플, 약 100 pulse/분")
        log("[가상센서] Android SensorManager/다른 앱의 센서 값은 변경하지 않습니다.")
        mainHandler.removeCallbacks(virtualShakeTick)
        mainHandler.post(virtualShakeTick)
        renderSensorValues(force = true)
    }

    private fun stopVirtualShakeQa() {
        virtualShakeRunning = false
        mainHandler.removeCallbacks(virtualShakeTick)
        virtualShakeButton.text = "2. 가상 흔들림 QA 시작"
        statusView.text = "상태: 가상 가속도 QA 중지"
        log("[가상센서] 중지 / 감지=$virtualDetectedSteps")
        renderSensorValues(force = true)
    }

    private fun processVirtualAccelerationSample(magnitude: Double, timestampNs: Long) {
        virtualAccelMagnitude = magnitude
        virtualGravityEstimate = virtualGravityEstimate * 0.90 + magnitude * 0.10
        val dynamic = magnitude - virtualGravityEstimate
        virtualFilteredDynamic = virtualFilteredDynamic * 0.65 + dynamic * 0.35

        if (virtualFilteredDynamic > FALLBACK_THRESHOLD &&
            timestampNs - virtualLastStepNs > FALLBACK_REFRACTORY_NS
        ) {
            virtualDetectedSteps++
            virtualLastStepNs = timestampNs
            localQaSteps++
            persistLocalCount()
            renderLocalCount()
            if (virtualDetectedSteps % 10 == 0) {
                log("[가상센서] 감지 $virtualDetectedSteps / 로컬 QA=$localQaSteps")
            }
        }
    }

    private fun startAutoQa() {
        if (autoQaRunning) return
        autoQaRunning = true
        autoButton.text = "자동 QA 카운터 중지"
        statusView.text = "상태: 자동 QA 카운터 실행 중"
        log("[QA] 자동 카운터 시작: 약 100보/분, 앱 내부 전용")
        mainHandler.removeCallbacks(autoQaTick)
        mainHandler.post(autoQaTick)
    }

    private fun stopAutoQa() {
        autoQaRunning = false
        mainHandler.removeCallbacks(autoQaTick)
        autoButton.text = "3. 자동 QA 카운터 시작"
        statusView.text = "상태: 자동 QA 카운터 중지"
        log("[QA] 자동 카운터 중지 → $localQaSteps 보")
    }

    private fun persistLocalCount() {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putInt(PREF_LOCAL_STEPS, localQaSteps)
            .apply()
    }

    private fun safeUi(action: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, action, t)
            if (::statusView.isInitialized) statusView.text = "상태: $action 실패"
            if (::logView.isInitialized) {
                log("[오류] $action: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
                t.cause?.let { log("[원인] ${it.javaClass.simpleName}: ${it.message ?: "메시지 없음"}") }
            }
        }
    }

    private fun runSelfTest() {
        statusView.text = "상태: 앱 내부 자체 점검 완료"
        log("===== 자체 점검 =====")
        log("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
        log("Android ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
        log("ACTIVITY_RECOGNITION: ${activityPermissionText()}")
        log("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
        log("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
        log("ACCELEROMETER: ${describeSensor(accelerometer)}")
        log("가상 흔들림 QA: ${if (virtualShakeRunning) "실행 중" else "중지"} / 감지=$virtualDetectedSteps")
        log("자동 QA 카운터: ${if (autoQaRunning) "실행 중" else "중지"}")
        log("로컬 QA 값: $localQaSteps")
        log("UI 이벤트: 정상")
        log("====================")
    }

    private fun requestAndStartSensors() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            statusView.text = "상태: 활동 인식 권한 요청 중"
            log("[센서] STEP_COUNTER/STEP_DETECTOR 사용을 위해 활동 인식 권한을 요청합니다.")
            log("[센서] 거부해도 가속도계 폴백은 계속 사용할 수 있습니다.")
            activityPermissionLauncher.launch(Manifest.permission.ACTIVITY_RECOGNITION)
            return
        }
        startSensorsNow(includeStepSensors = true)
    }

    private fun startSensorsNow(includeStepSensors: Boolean) {
        if (!::sensorManager.isInitialized) {
            statusView.text = "상태: SensorManager 초기화 실패"
            return
        }

        sensorManager.unregisterListener(this)
        registeredStepCounter = false
        registeredStepDetector = false
        registeredAccelerometer = false

        if (includeStepSensors) {
            stepCounterSensor?.let {
                registeredStepCounter = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
            stepDetectorSensor?.let {
                registeredStepDetector = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }

        accelerometer?.let {
            registeredAccelerometer = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }

        sensorListening = registeredStepCounter || registeredStepDetector || registeredAccelerometer
        sensorButton.text = if (sensorListening) "센서 진단 중지" else "1. 센서 진단 시작"
        statusView.text = when {
            registeredStepCounter || registeredStepDetector -> "상태: 걸음 센서 진단 실행 중"
            registeredAccelerometer -> "상태: 가속도계 폴백 진단 실행 중"
            else -> "상태: 등록 가능한 센서 없음"
        }
        log("[센서] STEP_COUNTER 등록=$registeredStepCounter")
        log("[센서] STEP_DETECTOR 등록=$registeredStepDetector")
        log("[센서] ACCELEROMETER 등록=$registeredAccelerometer")
        renderSensorValues(force = true)
    }

    private fun stopSensors() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        sensorListening = false
        registeredStepCounter = false
        registeredStepDetector = false
        registeredAccelerometer = false
        sensorButton.text = "1. 센서 진단 시작"
        statusView.text = "상태: 센서 진단 중지"
        log("[센서] 진단 중지")
        renderSensorValues(force = true)
    }

    override fun onSensorChanged(event: SensorEvent) {
        try {
            when (event.sensor.type) {
                Sensor.TYPE_STEP_COUNTER -> latestStepCounter = event.values.firstOrNull()
                Sensor.TYPE_STEP_DETECTOR -> if ((event.values.firstOrNull() ?: 0f) > 0f) detectorEvents++
                Sensor.TYPE_ACCELEROMETER -> processAccelerometer(event)
            }
            renderSensorValues(force = false)
        } catch (t: Throwable) {
            Log.e(TAG, "onSensorChanged", t)
        }
    }

    private fun processAccelerometer(event: SensorEvent) {
        val x = event.values.getOrElse(0) { 0f }.toDouble()
        val y = event.values.getOrElse(1) { 0f }.toDouble()
        val z = event.values.getOrElse(2) { 0f }.toDouble()
        val magnitude = sqrt(x * x + y * y + z * z)
        latestAccelMagnitude = magnitude
        gravityEstimate = gravityEstimate * 0.90 + magnitude * 0.10
        val dynamic = magnitude - gravityEstimate
        filteredDynamic = filteredDynamic * 0.65 + dynamic * 0.35

        if (!registeredStepCounter && !registeredStepDetector && registeredAccelerometer) {
            val now = event.timestamp
            if (filteredDynamic > FALLBACK_THRESHOLD && now - lastFallbackStepNs > FALLBACK_REFRACTORY_NS) {
                fallbackAccelSteps++
                lastFallbackStepNs = now
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun activityPermissionText(): String =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
        ) "승인" else "미승인"

    private fun renderPlatformInfo() {
        platformInfoView.text = buildString {
            appendLine("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("활동 인식 권한: ${activityPermissionText()}")
            appendLine("패키지: $packageName")
            append("권한 거부 시: 가속도계 폴백 허용")
        }
    }

    private fun renderLocalCount() {
        localCountView.text = buildString {
            append("앱 내부 QA 테스트 카운트: $localQaSteps 보")
            if (autoQaRunning) append("  (자동 증가 중)")
            if (virtualShakeRunning) append("  (가상 흔들림 중)")
        }
    }

    private fun renderSensorValues(force: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastUiRefreshMs < UI_REFRESH_MS) return
        lastUiRefreshMs = now

        sensorInfoView.text = buildString {
            appendLine("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
            appendLine("  등록: $registeredStepCounter / 부팅 이후 누적값: ${latestStepCounter ?: "미수신"}")
            appendLine("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
            appendLine("  등록: $registeredStepDetector / 진단 이벤트: $detectorEvents")
            appendLine("ACCELEROMETER(실제): ${describeSensor(accelerometer)}")
            appendLine("  등록: $registeredAccelerometer / |a|: ${"%.3f".format(Locale.US, latestAccelMagnitude)} m/s²")
            appendLine("  실제 가속도 폴백 계수: $fallbackAccelSteps")
            appendLine("ACCELEROMETER(가상 QA): ${if (virtualShakeRunning) "실행 중" else "중지"}")
            appendLine("  합성 |a|: ${"%.3f".format(Locale.US, virtualAccelMagnitude)} m/s²")
            appendLine("  동일 필터 감지: $virtualDetectedSteps")
            append("실제 센서 진단: ${if (sensorListening) "실행 중" else "중지"}")
        }
    }

    private fun describeSensor(sensor: Sensor?): String =
        sensor?.let { "${it.name} / vendor=${it.vendor}" } ?: "없음"

    private fun log(message: String) {
        Log.i(TAG, message)
        logView.append(message)
        if (!message.endsWith("\n")) logView.append("\n")
    }

    override fun onDestroy() {
        autoQaRunning = false
        virtualShakeRunning = false
        mainHandler.removeCallbacks(autoQaTick)
        mainHandler.removeCallbacks(virtualShakeTick)
        try {
            if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        } catch (_: Throwable) {
        }
        super.onDestroy()
    }
}
