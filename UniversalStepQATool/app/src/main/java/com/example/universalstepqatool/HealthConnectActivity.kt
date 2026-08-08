package com.example.universalstepqatool

import android.content.Intent
import android.os.Build
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
        private const val ACTION_MANAGE_HEALTH_PERMISSIONS = "android.health.connect.action.MANAGE_HEALTH_PERMISSIONS"
        private const val EXTRA_PACKAGE_NAME = "android.intent.extra.PACKAGE_NAME"
        private const val PREFS = "hc_permission_prefs"
        private const val KEY_DENIAL_COUNT = "read_steps_denial_count"
    }

    private lateinit var statusView: TextView
    private lateinit var permissionStateView: TextView
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
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().putInt(KEY_DENIAL_COUNT, 0).apply()
                statusView.text = "상태: READ_STEPS 권한 승인"
                log("[권한] READ_STEPS 승인됨")
            } else {
                val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
                val denied = prefs.getInt(KEY_DENIAL_COUNT, 0) + 1
                prefs.edit().putInt(KEY_DENIAL_COUNT, denied).apply()
                statusView.text = if (denied >= 2) {
                    "상태: 권한 요청 취소 반복 - 설정에서 직접 허용 필요"
                } else {
                    "상태: READ_STEPS 권한 미승인"
                }
                log("[권한] READ_STEPS 미승인 / 취소·거부 누적=$denied")
                if (denied >= 2) {
                    log("[권한] Android는 반복 취소 후 권한 팝업을 다시 표시하지 않을 수 있습니다.")
                    log("[권한] '이 앱의 Health Connect 권한 설정 열기' 버튼을 사용하세요.")
                }
            }
            refreshPermissionState()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_connect)

        statusView = findViewById(R.id.hcStatus)
        permissionStateView = findViewById(R.id.hcPermissionState)
        logView = findViewById(R.id.hcLog)

        bindButtons()
        log("Health Connect v6 권한 진단 화면 시작")
        log("패키지: $packageName")
        log("이 화면은 READ_STEPS 읽기/권한 진단 전용입니다.")
        refreshPermissionState()
    }

    override fun onResume() {
        super.onResume()
        if (::permissionStateView.isInitialized) refreshPermissionState()
    }

    private fun bindButtons() {
        findViewById<Button>(R.id.hcCheckButton).setOnClickListener {
            refreshPermissionState()
        }
        findViewById<Button>(R.id.hcPermissionButton).setOnClickListener {
            requestPermissionsSafe()
        }
        findViewById<Button>(R.id.hcManageAccessButton).setOnClickListener {
            openManageAccess()
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

    private fun refreshPermissionState() {
        launchSafe("권한 상태 재검사") {
            val available = refreshClient()
            if (!available) {
                permissionStateView.text = buildString {
                    appendLine("Health Connect: ${statusText()}")
                    appendLine("READ_STEPS: 확인 불가")
                    append("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
                }
                statusView.text = "상태: ${statusText()}"
                return@launchSafe
            }

            val hc = client ?: return@launchSafe
            val granted = hc.permissionController.getGrantedPermissions()
            val hasRead = granted.contains(readPermission)
            val deniedCount = getSharedPreferences(PREFS, MODE_PRIVATE).getInt(KEY_DENIAL_COUNT, 0)

            permissionStateView.text = buildString {
                appendLine("Health Connect: ${statusText()}")
                appendLine("READ_STEPS: ${if (hasRead) "승인" else "미승인"}")
                appendLine("권한 문자열: $readPermission")
                appendLine("패키지: $packageName")
                appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
                append("취소/거부 누적: $deniedCount")
            }
            statusView.text = if (hasRead) "상태: READ_STEPS 승인됨" else "상태: READ_STEPS 미승인"
            log("[재검사] READ_STEPS=${if (hasRead) "승인" else "미승인"}")
        }
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
                    refreshPermissionState()
                } else {
                    statusView.text = "상태: 시스템 READ_STEPS 권한 화면 여는 중"
                    log("[권한] Health Connect READ_STEPS 권한 화면 요청")
                    try {
                        permissionLauncher.launch(permissions)
                    } catch (t: Throwable) {
                        statusView.text = "상태: 권한 화면 실행 실패"
                        logThrowable("권한 화면 실행", t)
                        log("[권한] 아래 '이 앱의 Health Connect 권한 설정 열기'를 사용하세요.")
                    }
                }
            }
        }
    }

    private fun openManageAccess() {
        safeUi("Health Connect 권한 설정") {
            val candidates = mutableListOf<Intent>()
            if (Build.VERSION.SDK_INT >= 34) {
                candidates += Intent(ACTION_MANAGE_HEALTH_PERMISSIONS).apply {
                    putExtra(EXTRA_PACKAGE_NAME, packageName)
                }
            }
            candidates += Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)

            val target = candidates.firstOrNull { it.resolveActivity(packageManager) != null }
            if (target == null) {
                statusView.text = "상태: Health Connect 권한 설정 화면을 찾을 수 없음"
                log("[설정] 권한 관리 Activity를 찾지 못했습니다.")
                return@safeUi
            }
            log("[설정] 이 앱의 Health Connect 권한 관리 화면을 엽니다.")
            startActivity(target)
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
                log("[조회] READ_STEPS 권한이 없습니다.")
                log("[조회] 1) 권한 요청 → 안 뜨면 2) 권한 설정 직접 열기 순서로 사용하세요.")
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
                if (::statusView.isInitialized) statusView.text = "상태: $action 실패"
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
