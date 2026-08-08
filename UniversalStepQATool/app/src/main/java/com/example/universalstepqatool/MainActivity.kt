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
    }

    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var sensorListening = false

    private lateinit var statusView: TextView
    private lateinit var platformInfoView: TextView
    private lateinit var sensorInfoView: TextView
    private lateinit var localCountView: TextView
    private lateinit var logView: TextView
    private lateinit var sensorButton: Button

    private var latestStepCounter: Float? = null
    private var detectorEvents = 0
    private var fallbackAccelSteps = 0
    private var localQaSteps = 0
    private var latestAccelMagnitude = 0.0
    private var filteredDynamic = 0.0
    private var gravityEstimate = 9.81
    private var lastFallbackStepNs = 0L
    private var lastUiRefreshMs = 0L

    private val activityPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        safeUi("활동 인식 권한 결과") {
            if (granted) {
                log("[권한] ACTIVITY_RECOGNITION 승인")
                startSensorsNow()
            } else {
                statusView.text = "상태: 활동 인식 권한 거부됨"
                log("[권한] 거부됨. 가속도계만 가능한 기기에서는 일부 진단을 계속 사용할 수 있습니다.")
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

        log("앱 시작: v4 코어 분리 안정화판")
        log("메인 화면은 외부 앱/설정/Health Connect를 직접 호출하지 않습니다.")
        log("Health Connect는 별도 내부 화면에서만 실행됩니다.")
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
        findViewById<Button>(R.id.add100Button).setOnClickListener {
            safeUi("QA +100") {
                localQaSteps += 100
                renderLocalCount()
                log("[QA] 로컬 테스트 카운트 +100 → $localQaSteps")
            }
        }
        findViewById<Button>(R.id.add1000Button).setOnClickListener {
            safeUi("QA +1000") {
                localQaSteps += 1000
                renderLocalCount()
                log("[QA] 로컬 테스트 카운트 +1000 → $localQaSteps")
            }
        }
        findViewById<Button>(R.id.resetButton).setOnClickListener {
            safeUi("QA 초기화") {
                localQaSteps = 0
                detectorEvents = 0
                fallbackAccelSteps = 0
                renderLocalCount()
                renderSensorValues(force = true)
                log("[QA] 앱 내부 테스트 값 초기화")
            }
        }
        findViewById<Button>(R.id.healthConnectButton).setOnClickListener {
            safeUi("Health Connect 내부 화면") {
                val intent = Intent(this, HealthConnectActivity::class.java)
                startActivity(intent)
                log("[이동] 앱 내부 Health Connect 화면 열기")
            }
        }
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
        log("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
        log("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
        log("ACCELEROMETER: ${describeSensor(accelerometer)}")
        log("UI 이벤트: 정상")
        log("외부 Activity 호출: 없음")
        log("====================")
    }

    private fun requestAndStartSensors() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            statusView.text = "상태: 활동 인식 권한 요청 중"
            log("[센서] Android 활동 인식 권한을 요청합니다.")
            activityPermissionLauncher.launch(Manifest.permission.ACTIVITY_RECOGNITION)
            return
        }
        startSensorsNow()
    }

    private fun startSensorsNow() {
        var anyRegistered = false
        stepCounterSensor?.let {
            anyRegistered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) || anyRegistered
        }
        stepDetectorSensor?.let {
            anyRegistered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) || anyRegistered
        }
        accelerometer?.let {
            anyRegistered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) || anyRegistered
        }
        sensorListening = anyRegistered
        sensorButton.text = if (sensorListening) "센서 진단 중지" else "센서 진단 시작"
        statusView.text = if (sensorListening) "상태: 센서 진단 실행 중" else "상태: 등록 가능한 센서 없음"
        log("[센서] 등록 결과: ${if (sensorListening) "성공" else "실패/미지원"}")
        renderSensorValues(force = true)
    }

    private fun stopSensors() {
        if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        sensorListening = false
        sensorButton.text = "센서 진단 시작"
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

        if (stepCounterSensor == null && stepDetectorSensor == null) {
            val now = event.timestamp
            if (filteredDynamic > FALLBACK_THRESHOLD && now - lastFallbackStepNs > FALLBACK_REFRACTORY_NS) {
                fallbackAccelSteps++
                lastFallbackStepNs = now
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun renderPlatformInfo() {
        val activityPermission = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
        ) "승인" else "미승인"

        platformInfoView.text = buildString {
            appendLine("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("활동 인식 권한: $activityPermission")
            append("메인 화면 외부 호출: 없음")
        }
    }

    private fun renderLocalCount() {
        localCountView.text = "앱 내부 QA 테스트 카운트: $localQaSteps 보"
    }

    private fun renderSensorValues(force: Boolean) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastUiRefreshMs < UI_REFRESH_MS) return
        lastUiRefreshMs = now

        sensorInfoView.text = buildString {
            appendLine("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
            appendLine("  부팅 이후 누적값: ${latestStepCounter ?: "미수신"}")
            appendLine("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
            appendLine("  진단 이벤트 수: $detectorEvents")
            appendLine("ACCELEROMETER: ${describeSensor(accelerometer)}")
            appendLine("  |a|: ${"%.3f".format(Locale.US, latestAccelMagnitude)} m/s²")
            appendLine("  전용 걸음센서 없을 때 보조 계수: $fallbackAccelSteps")
            append("진단 상태: ${if (sensorListening) "실행 중" else "중지"}")
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
        try {
            if (::sensorManager.isInitialized) sensorManager.unregisterListener(this)
        } catch (_: Throwable) {
        }
        super.onDestroy()
    }
}
