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
import android.util.Log
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.sqrt

class MainActivity : AppCompatActivity(), SensorEventListener {

    companion object {
        private const val TAG = "UniversalStepQATool"
        private const val REQUEST_ACTIVITY_RECOGNITION = 1002
        private const val FALLBACK_THRESHOLD = 1.35
        private const val FALLBACK_REFRACTORY_NS = 280_000_000L
    }

    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var sensorListening = false

    private lateinit var statusView: TextView
    private lateinit var platformInfoView: TextView
    private lateinit var sensorInfoView: TextView
    private lateinit var logView: TextView
    private lateinit var stepsInput: EditText
    private lateinit var durationInput: EditText

    private var latestStepCounter: Float? = null
    private var detectorEvents = 0
    private var fallbackAccelSteps = 0
    private var latestAccelMagnitude = 0.0
    private var filteredDynamic = 0.0
    private var gravityEstimate = 9.81
    private var lastFallbackStepNs = 0L

    private var healthClient: HealthConnectClient? = null
    private val healthPermissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class)
    )

    private val healthPermissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        if (granted.containsAll(healthPermissions)) {
            statusView.text = "상태: Health Connect 걸음 읽기/쓰기 권한 승인"
            log("Health Connect 권한 승인 완료")
        } else {
            statusView.text = "상태: Health Connect 권한 일부/전체 거부"
            log("Health Connect 권한이 충분하지 않습니다.")
        }
        renderPlatformAvailability()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusView = findViewById(R.id.status)
        platformInfoView = findViewById(R.id.platformInfo)
        sensorInfoView = findViewById(R.id.sensorInfo)
        logView = findViewById(R.id.logView)
        stepsInput = findViewById(R.id.stepsInput)
        durationInput = findViewById(R.id.durationInput)

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepDetectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        configureHealthConnect()
        renderPlatformAvailability()
        renderSensorValues()
        requestActivityRecognitionIfNeeded()

        findViewById<Button>(R.id.authButton).setOnClickListener { requestHealthPermissions() }
        findViewById<Button>(R.id.readButton).setOnClickListener { readTodaySteps() }
        findViewById<Button>(R.id.writeButton).setOnClickListener {
            writeSteps(readStepInput(), readDurationInput())
        }
        findViewById<Button>(R.id.precisionButton).setOnClickListener {
            precisionTest(readStepInput(), readDurationInput())
        }
        findViewById<Button>(R.id.sensorButton).setOnClickListener {
            if (sensorListening) stopSensorDiagnostics() else startSensorDiagnostics()
        }
        findViewById<Button>(R.id.settingsButton).setOnClickListener { openHealthConnectSettings() }

        val autoWrite = intent.getBooleanExtra("autoWrite", false)
        val steps = intent.getIntExtra("steps", -1)
        val duration = intent.getIntExtra("durationMinutes", 10)
        if (autoWrite && steps > 0) {
            stepsInput.setText(steps.toString())
            durationInput.setText(duration.coerceAtLeast(1).toString())
            log("ADB autoWrite 요청 감지: $steps 보 / $duration 분")
            writeSteps(steps, duration.coerceAtLeast(1))
        }
    }

    private fun configureHealthConnect() {
        healthClient = when (HealthConnectClient.getSdkStatus(this)) {
            HealthConnectClient.SDK_AVAILABLE -> try {
                HealthConnectClient.getOrCreate(this)
            } catch (e: Exception) {
                log("Health Connect 초기화 실패: ${e.message}")
                null
            }
            else -> null
        }
    }

    private fun renderPlatformAvailability() {
        val status = HealthConnectClient.getSdkStatus(this)
        val healthText = when (status) {
            HealthConnectClient.SDK_AVAILABLE -> "사용 가능"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "설치 또는 업데이트 필요"
            else -> "이 기기/프로필에서는 사용 불가"
        }
        platformInfoView.text = buildString {
            appendLine("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("Health Connect: $healthText")
            append("제조사 전용 SDK 의존성: 없음")
        }
    }

    private fun requestHealthPermissions() {
        val client = healthClient
        if (client == null) {
            statusView.text = "상태: Health Connect 사용 불가"
            log("Health Connect가 없거나 지원되지 않습니다. 센서 진단은 그대로 사용할 수 있습니다.")
            return
        }
        lifecycleScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                if (granted.containsAll(healthPermissions)) {
                    statusView.text = "상태: Health Connect 권한 이미 승인됨"
                    log("Health Connect 권한이 이미 승인되어 있습니다.")
                } else {
                    healthPermissionLauncher.launch(healthPermissions)
                }
            } catch (e: Exception) {
                log("Health Connect 권한 확인 실패: ${e.message}")
            }
        }
    }

    private fun writeSteps(steps: Int, durationMinutes: Int, after: (() -> Unit)? = null) {
        if (steps <= 0) {
            log("걸음 수는 1 이상이어야 합니다.")
            return
        }
        val client = healthClient
        if (client == null) {
            statusView.text = "상태: Health Connect 쓰기 불가"
            log("이 기기에서는 Health Connect 쓰기를 사용할 수 없습니다. 앱 센서 진단은 정상 동작합니다.")
            return
        }

        lifecycleScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.contains(HealthPermission.getWritePermission(StepsRecord::class))) {
                    statusView.text = "상태: Health Connect 쓰기 권한 필요"
                    log("먼저 Health Connect 권한을 승인하세요.")
                    healthPermissionLauncher.launch(healthPermissions)
                    return@launch
                }

                val end = Instant.now()
                val start = end.minusSeconds(TimeUnit.MINUTES.toSeconds(durationMinutes.toLong().coerceAtLeast(1)))
                val record = StepsRecord(
                    count = steps.toLong(),
                    startTime = start,
                    endTime = end,
                    startZoneOffset = ZoneOffset.systemDefault().rules.getOffset(start),
                    endZoneOffset = ZoneOffset.systemDefault().rules.getOffset(end),
                    metadata = Metadata.manualEntry(
                        device = Device(
                            manufacturer = Build.MANUFACTURER,
                            model = Build.MODEL,
                            type = Device.TYPE_PHONE
                        )
                    )
                )

                statusView.text = "상태: Health Connect 기록 중..."
                client.insertRecords(listOf(record))
                statusView.text = "상태: Health Connect 기록 성공 (+$steps)"
                log("Health Connect 기록 성공: +$steps 보 / ${formatTime(start.toEpochMilli())} ~ ${formatTime(end.toEpochMilli())}")
                after?.invoke()
            } catch (e: Exception) {
                statusView.text = "상태: Health Connect 기록 실패"
                log("기록 실패: ${e.javaClass.simpleName}: ${e.message}")
            }
        }
    }

    private fun readTodaySteps(onResult: ((String) -> Unit)? = null) {
        val client = healthClient
        if (client == null) {
            statusView.text = "상태: Health Connect 조회 불가"
            val text = "Health Connect 미지원/미설치 기기입니다."
            log(text)
            onResult?.invoke(text)
            return
        }

        lifecycleScope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.contains(HealthPermission.getReadPermission(StepsRecord::class))) {
                    statusView.text = "상태: Health Connect 읽기 권한 필요"
                    log("먼저 Health Connect 권한을 승인하세요.")
                    healthPermissionLauncher.launch(healthPermissions)
                    return@launch
                }

                val zone = ZoneId.systemDefault()
                val start = LocalDate.now(zone).atStartOfDay(zone).toInstant()
                val end = Instant.now()
                val response = client.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end)
                    )
                )
                val total = response[StepsRecord.COUNT_TOTAL] ?: 0L
                val text = "오늘 Health Connect 합계: $total 보"
                statusView.text = "상태: 오늘 걸음 조회 성공"
                log(text)
                onResult?.invoke(text)
            } catch (e: Exception) {
                statusView.text = "상태: 오늘 걸음 조회 실패"
                val text = "오늘 걸음 조회 실패: ${e.javaClass.simpleName}: ${e.message}"
                log(text)
                onResult?.invoke(text)
            }
        }
    }

    private fun precisionTest(steps: Int, durationMinutes: Int) {
        log("===== 범용 정밀 검증 시작 =====")
        log("목표 증가량: +$steps 보")
        readTodaySteps {
            log("기준값 조회 완료 → Health Connect 테스트 데이터 기록")
            writeSteps(steps, durationMinutes) {
                readTodaySteps { log("===== 범용 정밀 검증 종료 =====") }
            }
        }
    }

    private fun openHealthConnectSettings() {
        if (healthClient == null) {
            log("Health Connect 설정을 열 수 없습니다: 이 기기에서 사용 불가")
            return
        }
        try {
            startActivity(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))
        } catch (e: Exception) {
            log("Health Connect 설정 열기 실패: ${e.message}")
        }
    }

    private fun startSensorDiagnostics() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_ACTIVITY_RECOGNITION)
            log("ACTIVITY_RECOGNITION 권한이 필요합니다.")
            return
        }

        detectorEvents = 0
        fallbackAccelSteps = 0
        lastFallbackStepNs = 0L
        stepCounterSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        stepDetectorSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        accelerometer?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) }
        sensorListening = true
        log("물리 센서 진단 시작")
        if (stepCounterSensor == null && stepDetectorSensor == null && accelerometer != null) {
            log("전용 걸음 센서 없음 → 가속도계 기반 보조 계수 모드")
        } else if (stepCounterSensor == null && stepDetectorSensor == null && accelerometer == null) {
            log("사용 가능한 걸음/가속도 센서가 없습니다.")
        }
        renderSensorValues()
    }

    private fun stopSensorDiagnostics() {
        sensorManager.unregisterListener(this)
        sensorListening = false
        log("물리 센서 진단 중지")
        renderSensorValues()
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> latestStepCounter = event.values.firstOrNull()
            Sensor.TYPE_STEP_DETECTOR -> if ((event.values.firstOrNull() ?: 0f) > 0f) detectorEvents++
            Sensor.TYPE_ACCELEROMETER -> processAccelerometer(event)
        }
        renderSensorValues()
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

    private fun renderSensorValues() {
        sensorInfoView.text = buildString {
            appendLine("STEP_COUNTER: ${describeSensor(stepCounterSensor)}")
            appendLine("  부팅 이후 누적값: ${latestStepCounter ?: "미수신"}")
            appendLine("STEP_DETECTOR: ${describeSensor(stepDetectorSensor)}")
            appendLine("  진단 이벤트 수: $detectorEvents")
            appendLine("ACCELEROMETER: ${describeSensor(accelerometer)}")
            appendLine("  |a|: ${"%.3f".format(Locale.US, latestAccelMagnitude)} m/s²")
            appendLine("  보조 가속도 걸음 수: $fallbackAccelSteps")
            append("진단 상태: ${if (sensorListening) "실행 중" else "중지"}")
        }
    }

    private fun describeSensor(sensor: Sensor?): String =
        sensor?.let { "${it.name} / vendor=${it.vendor}" } ?: "없음"

    private fun requestActivityRecognitionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_ACTIVITY_RECOGNITION)
        }
    }

    private fun readStepInput(): Int =
        stepsInput.text?.toString()?.toIntOrNull()?.coerceIn(1, 100000) ?: 1000

    private fun readDurationInput(): Int =
        durationInput.text?.toString()?.toIntOrNull()?.coerceIn(1, 1440) ?: 10

    private fun formatTime(ms: Long): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA).format(Date(ms))

    private fun log(message: String) {
        Log.i(TAG, message)
        logView.append(message)
        if (!message.endsWith("\n")) logView.append("\n")
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }
}
