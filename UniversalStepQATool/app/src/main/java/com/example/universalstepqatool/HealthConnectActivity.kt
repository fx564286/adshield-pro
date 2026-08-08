package com.example.universalstepqatool

import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class HealthConnectActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "HealthConnectScreen"
    }

    private lateinit var statusView: TextView
    private lateinit var logView: TextView

    private var client: HealthConnectClient? = null
    private var sdkStatus: Int = HealthConnectClient.SDK_UNAVAILABLE

    private val readPermission = HealthPermission.getReadPermission(StepsRecord::class)
    private val permissions = setOf(readPermission)

    private val permissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        safeUi("권한 결과") {
            if (granted.contains(readPermission)) {
                statusView.text = "상태: Health Connect 걸음 읽기 권한 승인"
                log("[권한] READ_STEPS 승인됨")
            } else {
                statusView.text = "상태: Health Connect 읽기 권한 거부"
                log("[권한] READ_STEPS가 승인되지 않았습니다.")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_connect)

        statusView = findViewById(R.id.hcStatus)
        logView = findViewById(R.id.hcLog)

        bindButtons()
        refreshClient()
        log("Health Connect 읽기/권한 진단 화면 시작")
        log("이 화면은 Health Connect에 테스트 걸음을 기록하지 않습니다.")
    }

    private fun bindButtons() {
        findViewById<Button>(R.id.hcCheckButton).setOnClickListener {
            safeUi("Health Connect 상태 확인") {
                refreshClient()
                statusView.text = "상태: ${statusText()}"
                log("[상태] ${statusText()}")
            }
        }
        findViewById<Button>(R.id.hcPermissionButton).setOnClickListener {
            requestPermissionsSafe()
        }
        findViewById<Button>(R.id.hcReadButton).setOnClickListener {
            readStepsSafe()
        }
        findViewById<Button>(R.id.hcBackButton).setOnClickListener {
            safeUi("뒤로가기") { finish() }
        }
    }

    private fun refreshClient(): Boolean {
        return try {
            sdkStatus = HealthConnectClient.getSdkStatus(this)
            client = if (sdkStatus == HealthConnectClient.SDK_AVAILABLE) {
                HealthConnectClient.getOrCreate(this)
            } else null
            client != null
        } catch (t: Throwable) {
            sdkStatus = HealthConnectClient.SDK_UNAVAILABLE
            client = null
            log("[오류] Health Connect 초기화: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
            false
        }
    }

    private fun statusText(): String = when (sdkStatus) {
        HealthConnectClient.SDK_AVAILABLE -> if (client != null) "사용 가능" else "초기화 실패"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "설치/업데이트 필요"
        else -> "이 기기에서 사용 불가"
    }

    private fun requestPermissionsSafe() {
        safeUi("권한 요청 준비") {
            if (!refreshClient()) {
                statusView.text = "상태: ${statusText()}"
                log("[권한] Health Connect를 사용할 수 없어 권한 화면을 열지 않음")
                return@safeUi
            }
            launchSafe("권한 상태 확인") {
                val hc = client ?: return@launchSafe
                val granted = hc.permissionController.getGrantedPermissions()
                if (granted.contains(readPermission)) {
                    statusView.text = "상태: READ_STEPS 권한 이미 승인됨"
                    log("[권한] READ_STEPS 이미 승인되어 있음")
                } else {
                    statusView.text = "상태: 시스템 권한 화면 여는 중"
                    log("[권한] READ_STEPS 권한 화면을 엽니다.")
                    try {
                        permissionLauncher.launch(permissions)
                    } catch (t: Throwable) {
                        statusView.text = "상태: 권한 화면 실행 실패"
                        logThrowable("권한 화면 실행", t)
                    }
                }
            }
        }
    }

    private fun readStepsSafe() {
        if (!refreshClient()) {
            statusView.text = "상태: ${statusText()}"
            log("[조회] Health Connect 사용 불가")
            return
        }
        launchSafe("걸음 조회") {
            val hc = client ?: return@launchSafe
            val granted = hc.permissionController.getGrantedPermissions()
            if (!granted.contains(readPermission)) {
                statusView.text = "상태: READ_STEPS 권한 필요"
                log("[조회] 권한이 없습니다. 권한 요청 버튼을 먼저 사용하세요.")
                return@launchSafe
            }
            val total = readToday(hc)
            statusView.text = "상태: 오늘 Health Connect $total 보"
            log("[조회] 오늘 합계: $total 보")
        }
    }

    private suspend fun readToday(hc: HealthConnectClient): Long {
        val zone = ZoneId.systemDefault()
        val start = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val end = Instant.now()
        val response = hc.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )
        )
        return response[StepsRecord.COUNT_TOTAL] ?: 0L
    }

    private fun safeUi(action: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            if (::statusView.isInitialized) statusView.text = "상태: $action 실패"
            logThrowable(action, t)
        }
    }

    private fun launchSafe(action: String, block: suspend () -> Unit) {
        lifecycleScope.launch {
            try {
                block()
            } catch (t: Throwable) {
                statusView.text = "상태: $action 실패"
                logThrowable(action, t)
            }
        }
    }

    private fun logThrowable(action: String, t: Throwable) {
        Log.e(TAG, action, t)
        log("[오류] $action: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
        t.cause?.let { log("[원인] ${it.javaClass.simpleName}: ${it.message ?: "메시지 없음"}") }
    }

    private fun log(message: String) {
        if (!::logView.isInitialized) return
        Log.i(TAG, message)
        logView.append(message)
        if (!message.endsWith("\n")) logView.append("\n")
    }
}
