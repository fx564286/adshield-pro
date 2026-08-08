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
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

class MainActivity : AppCompatActivity(), SensorEventListener {

    companion object {
        private const val TAG = "UniversalStepQATool"
        private const val UI_REFRESH_MS = 200L
        private const val AUTO_QA_INTERVAL_MS = 600L
        private const val VIRTUAL_SHAKE_INTERVAL_MS = 120L
        private const val PREFS = "qa_state"
        private const val PREF_LOCAL_STEPS = "local_steps"

        // Real accelerometer walking fallback. Kept deliberately conservative but responsive.
        private const val ACCEL_STEP_THRESHOLD = 1.05
        private const val ACCEL_RESET_THRESHOLD = 0.45
        private const val ACCEL_REFRACTORY_NS = 300_000_000L
    }

    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var accelerometer: Sensor? = null

    private lateinit var statusView: TextView
    private lateinit var platformInfoView: TextView
    private lateinit var actualSessionView: TextView
    private lateinit var sensorInfoView: TextView
    private lateinit var localCountView: TextView
    private lateinit var logView: TextView
    private lateinit var sensorButton: Button
    private lateinit var autoButton: Button
    private lateinit var virtualShakeButton: Button

    private var sensorListening = false
    private var registeredStepCounter = false
    private var registeredStepDetector = false
    private var registeredAccelerometer = false

    // Physical step sensor state.
    private var latestStepCounter: Float? = null
    private var counterBaseline: Float? = null
    private var counterSessionDelta = 0
    private var detectorSessionSteps = 0
    private var lastCounterEventElapsedMs = 0L
    private var lastDetectorEventElapsedMs = 0L

    // Physical accelerometer walking fallback state.
    private var realAccelSteps = 0
    private var latestAccelMagnitude = 0.0
    private var gravityEstimate = 9.81
    private var filteredDynamic = 0.0
    private var accelAboveThreshold = false
    private var lastAccelStepNs = 0L
    private var sensorSessionStartElapsedMs = 0L
    private var lastUiRefreshMs = 0L

    // QA-only local count.
    private var localQaSteps = 0

    // Internal-only synthetic acceleration QA state.
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
            localQaSteps++
            persistLocalCount()
            renderLocalCount()
            mainHandler.postDelayed(this, AUTO_QA_INTERVAL_MS)
        }
    }

    private val virtualShakeTick = object : Runnable {
        override fun run() {
            if (!virtualShakeRunning) return
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
            log("[권한] ACTIVITY_RECOGNITION=${if (granted) "승인" else "거부"}")
            // Always keep the real accelerometer active. Add hardware step sensors only when allowed.
            startSensorsNow(includeStepSensors = granted)
            renderPlatformInfo()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusView = findViewById(R.id.status)
        platformInfoView = findViewById(R.id.platformInfo)
        actualSessionView = findViewById(R.id.actualSessionView)
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
        renderActualSession()
        renderSensorValues(force = true)

        log("앱 시작: v9 실제 보행 병렬진단판")
        log("패키지: $packageName")
        log("핵심 수정: STEP_COUNTER가 0이어도 실제 가속도계 보행 검출을 병렬 수행")

        // Start immediately. If activity recognition is already allowed, all 3 sensor paths run.
        // If not, accelerometer walking detection still works without that permission.
        val hasActivity = hasActivityPermission()
        startSensorsNow(includeStepSensors = hasActivity)
    }

    override fun onResume() {
        super.onResume()
        if (::platformInfoView.isInitialized) {
            renderPlatformInfo()
            if (sensorListening && hasActivityPermission() && (!registeredStepCounter || !registeredStepDetector)) {
                startSensorsNow(includeStepSensors = true)
            }
        }
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
                virtualDetectedSteps = 0
                virtualAccelMagnitude = 9.81
                virtualGravityEstimate = 9.81
                virtualFilteredDynamic = 0.0
                virtualLastStepNs = 0L
                persistLocalCount()
                renderLocalCount()
                log("[QA] 앱 내부 테스트 값 초기화")
            }
        }
        findViewById<Button>(R.id.healthConnectButton).setOnClickListener {
            safeUi("Health Connect 내부 화면") {
                startActivity(Intent(this, HealthConnectActivity::class.java))
                log("[이동] Health Connect 읽기/권한 진단 화면")
            }
        }
    }

    private fun hasActivityPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    private fun requestAndStartSensors() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasActivityPermission()) {
            // Start real accelerometer immediately, then ask for step sensor permission.
            startSensorsNow(includeStepSensors = false)
            statusView.text = "상태: 실제 가속도 보행 감지 중 / 신체 활동 권한 요청"
            activityPermissionLauncher.launch(Manifest.permission.ACTIVITY_RECOGNITION)
            return
        }
        startSensorsNow(includeStepSensors = true)
    }

    private fun resetRealSession() {
        latestStepCounter = null
        counterBaseline = null
        counterSessionDelta = 0
        detectorSessionSteps = 0
        realAccelSteps = 0
        latestAccelMagnitude = 0.0
        gravityEstimate = 9.81
        filteredDynamic = 0.0
        accelAboveThreshold = false
        lastAccelStepNs = 0L
        lastCounterEventElapsedMs = 0L
        lastDetectorEventElapsedMs = 0L
        sensorSessionStartElapsedMs = SystemClock.elapsedRealtime()
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
        resetRealSession()

        if (includeStepSensors) {
            stepCounterSensor?.let {
                registeredStepCounter = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
            stepDetectorSensor?.let {
                registeredStepDetector = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }

        accelerometer?.let {
            // Higher sample rate than SENSOR_DELAY_UI so normal walking pulses are less likely to be missed.
            registeredAccelerometer = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }

        sensorListening = registeredStepCounter || registeredStepDetector || registeredAccelerometer
        sensorButton.text = if (sensorListening) "실제 센서 진단 중지" else "1. 실제 센서 진단 시작"
        statusView.text = when {
            registeredStepCounter || registeredStepDetector -> "상태: 실제 걸음 센서 + 가속도 병렬 진단 중"
            registeredAccelerometer -> "상태: 실제 가속도 보행 감지 중"
            else -> "상태: 등록 가능한 동작 센서 없음"
        }

        log("[센서] STEP_COUNTER 등록=$registeredStepCounter / ${describeSensor(stepCounterSensor)}")
        log("[센서] STEP_DETECTOR 등록=$registeredStepDetector / ${describeSensor(stepDetectorSensor)}")
        log("[센서] ACCELEROMETER 등록=$registeredAccelerometer / ${describeSensor(accelerometer)}")
        if (registeredStepCounter) log("[센서] STEP_COUNTER는 Android 공식상 최대 약 10초 지연 가능")
        renderActualSession()
        renderSensorValues(force = true)
    }

    private fun stopSensors() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        sensorListening = false
        registeredStepCounter = false
        registeredStepDetector = false
        registeredAccelerometer = false
        sensorButton.text = "1. 실제 센서 진단 시작"
        statusView.text = "상태: 실제 센서 진단 중지"
        log("[센서] 실제 센서 진단 중지")
        renderActualSession()
        renderSensorValues(force = true)
    }

    override fun onSensorChanged(event: SensorEvent) {
        try {
            when (event.sensor.type) {
                Sensor.TYPE_STEP_COUNTER -> {
                    val value = event.values.firstOrNull() ?: return
                    latestStepCounter = value
                    if (counterBaseline == null) counterBaseline = value
                    counterSessionDelta = max(0, (value - (counterBaseline ?: value)).toInt())
                    lastCounterEventElapsedMs = SystemClock.elapsedRealtime()
                }
                Sensor.TYPE_STEP_DETECTOR -> {
                    if ((event.values.firstOrNull() ?: 0f) > 0f) {
                        detectorSessionSteps++
                        lastDetectorEventElapsedMs = SystemClock.elapsedRealtime()
                    }
                }
                Sensor.TYPE_ACCELEROMETER -> processRealAccelerometer(event)
            }
            renderActualSession()
            renderSensorValues(force = false)
        } catch (t: Throwable) {
            Log.e(TAG, "onSensorChanged", t)
            log("[센서오류] ${t.javaClass.simpleName}: ${t.message}")
        }
    }

    private fun processRealAccelerometer(event: SensorEvent) {
        val x = event.values.getOrElse(0) { 0f }.toDouble()
        val y = event.values.getOrElse(1) { 0f }.toDouble()
        val z = event.values.getOrElse(2) { 0f }.toDouble()
        val magnitude = sqrt(x * x + y * y + z * z)
        latestAccelMagnitude = magnitude

        // Orientation-independent magnitude, with a slow gravity estimate.
        gravityEstimate = gravityEstimate * 0.92 + magnitude * 0.08
        val dynamic = magnitude - gravityEstimate
        filteredDynamic = filteredDynamic * 0.62 + dynamic * 0.38
        val activity = abs(filteredDynamic)

        if (!accelAboveThreshold && activity >= ACCEL_STEP_THRESHOLD) {
            accelAboveThreshold = true
            val nowNs = event.timestamp
            if (nowNs - lastAccelStepNs >= ACCEL_REFRACTORY_NS) {
                realAccelSteps++
                lastAccelStepNs = nowNs
            }
        } else if (accelAboveThreshold && activity <= ACCEL_RESET_THRESHOLD) {
            accelAboveThreshold = false
        }
    }

    private fun actualEffectiveSteps(): Int = max(counterSessionDelta, max(detectorSessionSteps, realAccelSteps))

    private fun actualEffectiveSource(): String {
        val maxValue = actualEffectiveSteps()
        return when {
            maxValue <= 0 -> "대기"
            detectorSessionSteps == maxValue -> "STEP_DETECTOR"
            counterSessionDelta == maxValue -> "STEP_COUNTER 증가량"
            else -> "실제 ACCELEROMETER 보행 검출"
        }
    }

    private fun renderActualSession() {
        if (!::actualSessionView.isInitialized) return
        actualSessionView.text = buildString {
            appendLine("실제 걷기 세션: ${actualEffectiveSteps()} 보")
            append("현재 기준 소스: ${actualEffectiveSource()}")
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
        log("[가상센서] 앱 내부 합성 샘플 시작")
        mainHandler.removeCallbacks(virtualShakeTick)
        mainHandler.post(virtualShakeTick)
        renderSensorValues(force = true)
    }

    private fun stopVirtualShakeQa() {
        virtualShakeRunning = false
        mainHandler.removeCallbacks(virtualShakeTick)
        virtualShakeButton.text = "2. 가상 흔들림 QA 시작"
        log("[가상센서] 중지 / 감지=$virtualDetectedSteps")
        renderSensorValues(force = true)
    }

    private fun processVirtualAccelerationSample(magnitude: Double, timestampNs: Long) {
        virtualAccelMagnitude = magnitude
        virtualGravityEstimate = virtualGravityEstimate * 0.90 + magnitude * 0.10
        val dynamic = magnitude - virtualGravityEstimate
        virtualFilteredDynamic = virtualFilteredDynamic * 0.65 + dynamic * 0.35
        if (virtualFilteredDynamic > 1.35 && timestampNs - virtualLastStepNs > 280_000_000L) {
            virtualDetectedSteps++
            virtualLastStepNs = timestampNs
        }
    }

    private fun startAutoQa() {
        if (autoQaRunning) return
        autoQaRunning = true
        autoButton.text = "자동 QA 카운터 중지"
        mainHandler.removeCallbacks(autoQaTick)
        mainHandler.post(autoQaTick)
    }

    private fun stopAutoQa() {
        autoQaRunning = false
        mainHandler.removeCallbacks(autoQaTick)
        autoButton.text = "3. 자동 QA 카운터 시작"
        log("[QA] 자동 카운터 중지 → $localQaSteps")
    }

    private fun persistLocalCount() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putInt(PREF_LOCAL_STEPS, localQaSteps).apply()
    }

    private fun renderLocalCount() {
        localCountView.text = buildString {
            append("QA 테스트 카운트: $localQaSteps 보")
            if (autoQaRunning) append(" (자동 증가 중)")
        }
    }

    private fun activityPermissionText(): String = if (hasActivityPermission()) "승인" else "미승인"

    private fun renderPlatformInfo() {
        platformInfoView.text = buildString {
            appendLine("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("신체 활동 권한: ${activityPermissionText()}")
            appendLine("패키지: $packageName")
            append("실제 가속도 보행 검출: 권한과 무관하게 병렬 사용")
        }
    }

    private fun renderSensorValues(force: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastUiRefreshMs < UI_REFRESH_MS) return
        lastUiRefreshMs = now

        fun age(last: Long): String = if (last <= 0L) "이벤트 없음" else "${now - last}ms 전"
        val elapsed = if (sensorSessionStartElapsedMs > 0) now - sensorSessionStartElapsedMs else 0L

        sensorInfoView.text = buildString {
            appendLine("[실제 센서 세션 ${elapsed}ms]")
            appendLine("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
            appendLine("  등록=$registeredStepCounter / raw=${latestStepCounter ?: "미수신"} / 세션Δ=$counterSessionDelta / ${age(lastCounterEventElapsedMs)}")
            appendLine("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
            appendLine("  등록=$registeredStepDetector / 세션=$detectorSessionSteps / ${age(lastDetectorEventElapsedMs)}")
            appendLine("ACCELEROMETER: ${describeSensor(accelerometer)}")
            appendLine("  등록=$registeredAccelerometer / |a|=${"%.3f".format(Locale.US, latestAccelMagnitude)} m/s²")
            appendLine("  필터=${"%.3f".format(Locale.US, filteredDynamic)} / 실제 보행=$realAccelSteps")
            appendLine("가상 QA: ${if (virtualShakeRunning) "실행" else "중지"} / 감지=$virtualDetectedSteps")
            append("최종 실제 세션=${actualEffectiveSteps()} / ${actualEffectiveSource()}")
        }
    }

    private fun describeSensor(sensor: Sensor?): String =
        sensor?.let {
            "${it.name} / vendor=${it.vendor} / wake=${it.isWakeUpSensor} / mode=${it.reportingMode}"
        } ?: "없음"

    private fun runSelfTest() {
        statusView.text = "상태: 자체 점검 완료"
        log("===== 실제 센서 자체 점검 =====")
        log("신체 활동 권한=${activityPermissionText()}")
        log("STEP_COUNTER=${describeSensor(stepCounterSensor)} 등록=$registeredStepCounter raw=${latestStepCounter ?: "없음"} Δ=$counterSessionDelta")
        log("STEP_DETECTOR=${describeSensor(stepDetectorSensor)} 등록=$registeredStepDetector session=$detectorSessionSteps")
        log("ACCEL=${describeSensor(accelerometer)} 등록=$registeredAccelerometer steps=$realAccelSteps")
        log("최종 실제 세션=${actualEffectiveSteps()} source=${actualEffectiveSource()}")
        log("================================")
    }

    private fun safeUi(action: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e(TAG, action, t)
            if (::statusView.isInitialized) statusView.text = "상태: $action 실패"
            if (::logView.isInitialized) log("[오류] $action: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
        }
    }

    private fun log(message: String) {
        Log.i(TAG, message)
        if (::logView.isInitialized) {
            logView.append(message)
            if (!message.endsWith("\n")) logView.append("\n")
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

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
