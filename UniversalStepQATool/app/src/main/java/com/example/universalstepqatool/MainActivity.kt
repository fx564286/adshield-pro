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
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
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
    private lateinit var sensorButton: Button

    private var latestStepCounter: Float? = null
    private var detectorEvents = 0
    private var fallbackAccelSteps = 0
    private var latestAccelMagnitude = 0.0
    private var filteredDynamic = 0.0
    private var gravityEstimate = 9.81
    private var lastFallbackStepNs = 0L

    private var healthStatus: Int = HealthConnectClient.SDK_UNAVAILABLE
    private var healthClient: HealthConnectClient? = null

    private val healthReadPermission = HealthPermission.getReadPermission(StepsRecord::class)
    private val healthWritePermission = HealthPermission.getWritePermission(StepsRecord::class)
    private val healthPermissions = setOf(healthReadPermission, healthWritePermission)

    private val healthPermissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract(PROVIDER_PACKAGE)
    ) { granted ->
        safeUi("Health Connect 권한 결과 처리") {
            if (granted.containsAll(healthPermissions)) {
                statusView.text = "상태: Health Connect 걸음 읽기/쓰기 권한 승인"
                log("[권한] Health Connect 읽기/쓰기 승인 완료")
            } else {
                statusView.text = "상태: Health Connect 권한 일부/전체 거부"
                log("[권한] 승인된 항목: ${granted.size}/${healthPermissions.size}")
                log("[안내] 권한을 거부해도 앱은 종료되지 않습니다. 필요한 경우 1번 버튼에서 다시 요청하세요.")
            }
            refreshHealthConnect()
            renderPlatformAvailability()
        }
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
        sensorButton = findViewById(R.id.sensorButton)

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepDetectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        refreshHealthConnect()
        renderPlatformAvailability()
        renderSensorValues()

        bindButtons()

        log("앱 시작: 버튼 안정화판 v3")
        log("Health Connect 권한/설정 버튼만 시스템 화면을 열 수 있습니다.")
        log("조회/기록/정밀검증 버튼은 권한이 없을 때 앱 밖으로 보내지 않고 화면에 원인만 표시합니다.")

        val autoWrite = intent.getBooleanExtra("autoWrite", false)
        val steps = intent.getIntExtra("steps", -1)
        val duration = intent.getIntExtra("durationMinutes", 10)
        if (autoWrite && steps > 0) {
            stepsInput.setText(steps.toString())
            durationInput.setText(duration.coerceAtLeast(1).toString())
            log("ADB autoWrite 요청 감지: $steps 보 / $duration 분")
            writeStepsFromUi()
        }
    }

    override fun onResume() {
        super.onResume()
        if (::statusView.isInitialized) {
            safeUi("화면 복귀 상태 갱신") {
                refreshHealthConnect()
                renderPlatformAvailability()
            }
        }
    }

    private fun bindButtons() {
        findViewById<Button>(R.id.selfTestButton).setOnClickListener {
            safeUi("앱 자체 점검") { runLocalSelfTest() }
        }
        findViewById<Button>(R.id.authButton).setOnClickListener {
            safeUi("Health Connect 권한") { requestHealthPermissions() }
        }
        findViewById<Button>(R.id.settingsButton).setOnClickListener {
            safeUi("Health Connect 설정") { openHealthConnectSettings() }
        }
        findViewById<Button>(R.id.readButton).setOnClickListener {
            readTodayStepsFromUi()
        }
        findViewById<Button>(R.id.writeButton).setOnClickListener {
            writeStepsFromUi()
        }
        findViewById<Button>(R.id.precisionButton).setOnClickListener {
            precisionTestFromUi()
        }
        sensorButton.setOnClickListener {
            safeUi("물리 센서 진단") {
                if (sensorListening) stopSensorDiagnostics() else startSensorDiagnostics()
            }
        }
    }

    private fun safeUi(action: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            statusView.text = "상태: $action 실패"
            logError(action, t)
        }
    }

    private fun launchSafe(action: String, block: suspend () -> Unit) {
        lifecycleScope.launch {
            try {
                block()
            } catch (t: Throwable) {
                statusView.text = "상태: $action 실패"
                logError(action, t)
            }
        }
    }

    private fun logError(action: String, t: Throwable) {
        Log.e(TAG, "$action 실패", t)
        log("[오류] $action: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
        val cause = t.cause
        if (cause != null && cause !== t) {
            log("[원인] ${cause.javaClass.simpleName}: ${cause.message ?: "메시지 없음"}")
        }
        log("[보호] 예외를 앱 내부에서 처리했습니다. 앱을 종료하지 않습니다.")
    }

    private fun refreshHealthConnect(): Boolean {
        return try {
            healthStatus = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
            healthClient = if (healthStatus == HealthConnectClient.SDK_AVAILABLE) {
                try {
                    HealthConnectClient.getOrCreate(this, PROVIDER_PACKAGE)
                } catch (t: Throwable) {
                    log("[Health Connect] 클라이언트 생성 실패: ${t.javaClass.simpleName}: ${t.message}")
                    null
                }
            } else {
                null
            }
            healthClient != null
        } catch (t: Throwable) {
            healthStatus = HealthConnectClient.SDK_UNAVAILABLE
            healthClient = null
            log("[Health Connect] 상태 확인 실패: ${t.javaClass.simpleName}: ${t.message}")
            false
        }
    }

    private fun renderPlatformAvailability() {
        val healthText = when (healthStatus) {
            HealthConnectClient.SDK_AVAILABLE -> if (healthClient != null) "사용 가능" else "상태는 사용 가능 / 연결 실패"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "설치 또는 업데이트 필요"
            else -> "이 기기/프로필에서는 사용 불가"
        }
        val activityPermission = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
        ) "승인" else "미승인"

        platformInfoView.text = buildString {
            appendLine("기기: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
            appendLine("Health Connect: $healthText")
            appendLine("활동 인식 권한: $activityPermission")
            append("제조사 전용 SDK 의존성: 없음")
        }
    }

    private fun runLocalSelfTest() {
        statusView.text = "상태: 앱 자체 점검 완료"
        log("===== 앱 자체 점검 =====")
        log("UI 이벤트: 정상")
        log("STEP_COUNTER: ${if (stepCounterSensor != null) "있음" else "없음"}")
        log("STEP_DETECTOR: ${if (stepDetectorSensor != null) "있음" else "없음"}")
        log("ACCELEROMETER: ${if (accelerometer != null) "있음" else "없음"}")
        refreshHealthConnect()
        log("Health Connect: ${healthStatusText()}")
        log("이 점검은 앱 밖으로 이동하지 않습니다.")
        log("========================")
        renderPlatformAvailability()
    }

    private fun healthStatusText(): String = when (healthStatus) {
        HealthConnectClient.SDK_AVAILABLE -> if (healthClient != null) "사용 가능" else "연결 실패"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "설치/업데이트 필요"
        else -> "사용 불가"
    }

    private fun requestHealthPermissions() {
        if (!refreshHealthConnect()) {
            statusView.text = "상태: Health Connect 권한 요청 불가"
            log("[권한] Health Connect ${healthStatusText()}")
            log("[안내] 이 상태에서는 권한 화면을 강제로 열지 않습니다.")
            renderPlatformAvailability()
            return
        }

        launchSafe("Health Connect 권한 확인") {
            val client = healthClient ?: return@launchSafe
            val granted = client.permissionController.getGrantedPermissions()
            if (granted.containsAll(healthPermissions)) {
                statusView.text = "상태: Health Connect 권한 이미 승인됨"
                log("[권한] 읽기/쓰기 권한이 이미 모두 승인되어 있습니다.")
            } else {
                statusView.text = "상태: Health Connect 시스템 권한 화면 여는 중"
                log("[권한] 지금부터 Android/Health Connect 시스템 권한 화면이 열립니다.")
                log("[권한] 이것은 앱 종료가 아니라 정상적인 외부 권한 화면 전환입니다.")
                healthPermissionLauncher.launch(healthPermissions)
            }
        }
    }

    private suspend fun hasHealthPermissions(required: Set<String>): Boolean {
        val client = healthClient ?: return false
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(required)
    }

    private fun requireHealthReady(action: String): HealthConnectClient? {
        if (!refreshHealthConnect()) {
            statusView.text = "상태: $action 불가"
            log("[$action] Health Connect ${healthStatusText()}")
            log("[$action] 앱은 종료되지 않았습니다.")
            renderPlatformAvailability()
            return null
        }
        return healthClient
    }

    private fun readTodayStepsFromUi() {
        val client = requireHealthReady("걸음 조회") ?: return
        launchSafe("오늘 걸음 조회") {
            if (!hasHealthPermissions(setOf(healthReadPermission))) {
                statusView.text = "상태: 걸음 조회 권한 필요"
                log("[조회] READ_STEPS 권한이 없습니다.")
                log("[조회] 1번 'Health Connect 권한 요청' 버튼에서 권한을 승인하세요.")
                log("[조회] 이 버튼은 더 이상 자동으로 외부 권한 화면을 열지 않습니다.")
                return@launchSafe
            }
            val total = readTodayStepsInternal(client)
            statusView.text = "상태: 오늘 걸음 조회 성공"
            log("[조회] 오늘 Health Connect 합계: $total 보")
        }
    }

    private fun writeStepsFromUi() {
        val steps = readStepInput()
        val duration = readDurationInput()
        val client = requireHealthReady("테스트 걸음 기록") ?: return
        launchSafe("테스트 걸음 기록") {
            if (!hasHealthPermissions(setOf(healthWritePermission))) {
                statusView.text = "상태: 걸음 기록 권한 필요"
                log("[기록] WRITE_STEPS 권한이 없습니다.")
                log("[기록] 1번 'Health Connect 권한 요청' 버튼에서 권한을 승인하세요.")
                log("[기록] 이 버튼은 더 이상 자동으로 외부 권한 화면을 열지 않습니다.")
                return@launchSafe
            }
            writeStepsInternal(client, steps, duration)
            statusView.text = "상태: Health Connect 테스트 기록 성공 (+$steps)"
        }
    }

    private fun precisionTestFromUi() {
        val steps = readStepInput()
        val duration = readDurationInput()
        val client = requireHealthReady("정밀 검증") ?: return
        launchSafe("정밀 검증") {
            if (!hasHealthPermissions(healthPermissions)) {
                statusView.text = "상태: 정밀 검증 권한 필요"
                log("[정밀검증] READ_STEPS와 WRITE_STEPS 권한이 모두 필요합니다.")
                log("[정밀검증] 먼저 1번 권한 버튼을 사용하세요. 앱 밖으로 자동 전환하지 않습니다.")
                return@launchSafe
            }

            statusView.text = "상태: 정밀 검증 실행 중"
            log("===== 정밀 검증 시작 =====")
            val before = readTodayStepsInternal(client)
            log("[정밀검증] 기록 전 합계: $before 보")
            writeStepsInternal(client, steps, duration)
            val after = readTodayStepsInternal(client)
            val delta = after - before
            log("[정밀검증] 기록 후 합계: $after 보")
            log("[정밀검증] 관측 증가량: $delta 보 / 요청: $steps 보")
            log("===== 정밀 검증 종료 =====")
            statusView.text = if (delta >= steps) {
                "상태: 정밀 검증 완료 (증가량 +$delta)"
            } else {
                "상태: 정밀 검증 완료 (증가량 +$delta, 확인 필요)"
            }
        }
    }

    private suspend fun readTodayStepsInternal(client: HealthConnectClient): Long {
        val zone = ZoneId.systemDefault()
        val start = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val end = Instant.now()
        val response = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )
        )
        return response[StepsRecord.COUNT_TOTAL] ?: 0L
    }

    private suspend fun writeStepsInternal(client: HealthConnectClient, steps: Int, durationMinutes: Int) {
        require(steps > 0) { "걸음 수는 1 이상이어야 합니다." }
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
        client.insertRecords(listOf(record))
        log("[기록] 테스트 걸음 저장 성공: +$steps 보 / ${formatTime(start.toEpochMilli())} ~ ${formatTime(end.toEpochMilli())}")
    }

    private fun openHealthConnectSettings() {
        if (!refreshHealthConnect()) {
            statusView.text = "상태: Health Connect 설정 열기 불가"
            log("[설정] Health Connect ${healthStatusText()}")
            log("[설정] 열 수 없는 외부 화면은 실행하지 않았습니다.")
            return
        }

        val primary = if (Build.VERSION.SDK_INT >= 34) {
            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
            }
        } else {
            Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        }
        val fallback = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        val intent = when {
            primary.resolveActivity(packageManager) != null -> primary
            fallback.resolveActivity(packageManager) != null -> fallback
            else -> null
        }

        if (intent == null) {
            statusView.text = "상태: Health Connect 설정 화면을 찾을 수 없음"
            log("[설정] 이 기기에서 처리 가능한 Health Connect 설정 Activity를 찾지 못했습니다.")
            return
        }

        statusView.text = "상태: Health Connect 시스템 설정 화면으로 이동"
        log("[설정] 지금부터 Android 시스템/Health Connect 설정 화면이 열립니다.")
        log("[설정] 이것은 앱 튕김이 아니라 의도된 외부 화면 전환입니다. 뒤로가기로 복귀하세요.")
        startActivity(intent)
    }

    private fun startSensorDiagnostics() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            statusView.text = "상태: 활동 인식 권한 요청"
            log("[센서] Android 활동 인식 권한이 필요합니다. 시스템 권한 팝업을 표시합니다.")
            requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_ACTIVITY_RECOGNITION)
            return
        }

        detectorEvents = 0
        fallbackAccelSteps = 0
        lastFallbackStepNs = 0L

        var registered = false
        stepCounterSensor?.let {
            registered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) || registered
        }
        stepDetectorSensor?.let {
            registered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) || registered
        }
        accelerometer?.let {
            registered = sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME) || registered
        }

        sensorListening = registered
        if (registered) {
            statusView.text = "상태: 물리 센서 진단 실행 중"
            sensorButton.text = "범용 물리 센서 진단 중지"
            log("[센서] 물리 센서 진단 시작")
        } else {
            statusView.text = "상태: 등록 가능한 센서 없음"
            sensorButton.text = "범용 물리 센서 진단 시작"
            log("[센서] 센서가 없거나 리스너 등록에 실패했습니다.")
        }

        if (stepCounterSensor == null && stepDetectorSensor == null && accelerometer != null) {
            log("[센서] 전용 걸음 센서 없음 → 가속도계 기반 보조 계수 모드")
        } else if (stepCounterSensor == null && stepDetectorSensor == null && accelerometer == null) {
            log("[센서] 사용 가능한 걸음/가속도 센서가 없습니다.")
        }
        renderSensorValues()
        renderPlatformAvailability()
    }

    private fun stopSensorDiagnostics() {
        sensorManager.unregisterListener(this)
        sensorListening = false
        sensorButton.text = "범용 물리 센서 진단 시작"
        statusView.text = "상태: 물리 센서 진단 중지"
        log("[센서] 물리 센서 진단 중지")
        renderSensorValues()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_ACTIVITY_RECOGNITION) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                log("[센서] 활동 인식 권한 승인 → 센서 진단을 시작합니다.")
                safeUi("물리 센서 진단 시작") { startSensorDiagnostics() }
            } else {
                statusView.text = "상태: 활동 인식 권한 거부"
                log("[센서] 활동 인식 권한이 거부되어 STEP_COUNTER/STEP_DETECTOR 진단을 시작하지 않았습니다.")
            }
            renderPlatformAvailability()
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        safeUi("센서 이벤트 처리") {
            when (event.sensor.type) {
                Sensor.TYPE_STEP_COUNTER -> latestStepCounter = event.values.firstOrNull()
                Sensor.TYPE_STEP_DETECTOR -> if ((event.values.firstOrNull() ?: 0f) > 0f) detectorEvents++
                Sensor.TYPE_ACCELEROMETER -> processAccelerometer(event)
            }
            renderSensorValues()
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

    private fun readStepInput(): Int =
        stepsInput.text?.toString()?.toIntOrNull()?.coerceIn(1, 100000) ?: 1000

    private fun readDurationInput(): Int =
        durationInput.text?.toString()?.toIntOrNull()?.coerceIn(1, 1440) ?: 10

    private fun formatTime(ms: Long): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA).format(Date(ms))

    private fun log(message: String) {
        Log.i(TAG, message)
        if (::logView.isInitialized) {
            logView.append(message)
            if (!message.endsWith("\n")) logView.append("\n")
        }
    }

    override fun onDestroy() {
        if (::sensorManager.isInitialized) {
            sensorManager.unregisterListener(this)
        }
        super.onDestroy()
    }
}
