package com.example.universalstepqatool

import android.content.ActivityNotFoundException
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
        private const val HC_PROVIDER = "com.google.android.apps.healthdata"
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

    private val readPermission: String by lazy {
        HealthPermission.getReadPermission(StepsRecord::class)
    }

    private val permissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        try {
            val hasRead = granted.contains(readPermission)
            if (hasRead) {
                getSharedPreferences(PREFS, MODE_PRIVATE)
                    .edit().putInt(KEY_DENIAL_COUNT, 0).apply()
                statusView.text = "상태: READ_STEPS 권한 승인"
                log("[권한결과] READ_STEPS 승인")
            } else {
                val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
                val denied = prefs.getInt(KEY_DENIAL_COUNT, 0) + 1
                prefs.edit().putInt(KEY_DENIAL_COUNT, denied).apply()
                statusView.text = if (denied >= 2) {
                    "상태: READ_STEPS 미승인 - Health Connect 설정에서 직접 허용 필요"
                } else {
                    "상태: READ_STEPS 미승인"
                }
                log("[권한결과] 미승인 / 누적=$denied")
            }
            refreshPermissionState()
        } catch (t: Throwable) {
            logThrowable("권한 결과 처리", t)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_connect)

        statusView = findViewById(R.id.hcStatus)
        permissionStateView = findViewById(R.id.hcPermissionState)
        logView = findViewById(R.id.hcLog)

        bindButtons()
        log("Health Connect v7 READ_STEPS 진단 시작")
        log("패키지=$packageName")
        log("Android=${Build.VERSION.RELEASE} / API=${Build.VERSION.SDK_INT}")
        log("READ permission=$readPermission")
        log(if (Build.VERSION.SDK_INT >= 34) {
            "권한모드=Android 14+ framework"
        } else {
            "권한모드=Android 13 이하 Health Connect APK 호환"
        })
        refreshPermissionState()
    }

    override fun onResume() {
        super.onResume()
        if (::permissionStateView.isInitialized) refreshPermissionState()
    }

    private fun bindButtons() {
        findViewById<Button>(R.id.hcCheckButton).setOnClickListener {
            safeUi("권한 상태 재검사") { refreshPermissionState() }
        }
        findViewById<Button>(R.id.hcPermissionButton).setOnClickListener {
            safeUi("READ_STEPS 권한 요청") { requestPermission() }
        }
        findViewById<Button>(R.id.hcManageAccessButton).setOnClickListener {
            safeUi("Health Connect 권한 설정") { openManageAccess() }
        }
        findViewById<Button>(R.id.hcReadButton).setOnClickListener {
            safeUi("오늘 걸음 조회") { readStepsSafe() }
        }
        findViewById<Button>(R.id.hcBackButton).setOnClickListener {
            finish()
        }
    }

    private fun refreshClient(): Boolean {
        return try {
            sdkStatus = HealthConnectClient.getSdkStatus(this)
            client = if (sdkStatus == HealthConnectClient.SDK_AVAILABLE) {
                HealthConnectClient.getOrCreate(this)
            } else {
                null
            }
            client != null
        } catch (t: Throwable) {
            client = null
            sdkStatus = HealthConnectClient.SDK_UNAVAILABLE
            logThrowable("Health Connect 초기화", t)
            false
        }
    }

    private fun statusText(): String = when (sdkStatus) {
        HealthConnectClient.SDK_AVAILABLE -> "사용 가능"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "Health Connect 설치/업데이트 필요"
        else -> "이 기기에서 Health Connect 사용 불가"
    }

    private fun refreshPermissionState() {
        lifecycleScope.launch {
            try {
                val available = refreshClient()
                val providerInstalled = try {
                    packageManager.getPackageInfo(HC_PROVIDER, 0)
                    true
                } catch (_: Throwable) {
                    false
                }

                if (!available) {
                    permissionStateView.text = buildString {
                        appendLine("Health Connect: ${statusText()}")
                        appendLine("SDK status: $sdkStatus")
                        appendLine("READ_STEPS: 확인 불가")
                        appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
                        append("Health Connect APK 설치: ${if (providerInstalled) "예" else "아니오/프레임워크 사용"}")
                    }
                    statusView.text = "상태: ${statusText()}"
                    return@launch
                }

                val hc = client ?: return@launch
                val granted = hc.permissionController.getGrantedPermissions()
                val hasRead = granted.contains(readPermission)
                val deniedCount = getSharedPreferences(PREFS, MODE_PRIVATE)
                    .getInt(KEY_DENIAL_COUNT, 0)

                permissionStateView.text = buildString {
                    appendLine("Health Connect: ${statusText()}")
                    appendLine("SDK status: $sdkStatus")
                    appendLine("READ_STEPS: ${if (hasRead) "승인" else "미승인"}")
                    appendLine("권한 문자열: $readPermission")
                    appendLine("Android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}")
                    appendLine("HC APK 설치: ${if (providerInstalled) "예" else "아니오/프레임워크"}")
                    append("취소/거부 누적: $deniedCount")
                }
                statusView.text = if (hasRead) {
                    "상태: READ_STEPS 승인됨"
                } else {
                    "상태: READ_STEPS 미승인"
                }
                log("[재검사] READ_STEPS=${if (hasRead) "승인" else "미승인"}")
            } catch (t: Throwable) {
                statusView.text = "상태: 권한 상태 확인 실패"
                logThrowable("권한 상태 재검사", t)
            }
        }
    }

    private fun requestPermission() {
        if (!refreshClient()) {
            statusView.text = "상태: ${statusText()}"
            log("[권한] Health Connect unavailable; 권한 UI를 실행하지 않음")
            return
        }

        lifecycleScope.launch {
            try {
                val hc = client ?: return@launch
                val granted = hc.permissionController.getGrantedPermissions()
                if (granted.contains(readPermission)) {
                    statusView.text = "상태: READ_STEPS 이미 승인됨"
                    log("[권한] 이미 승인됨")
                    return@launch
                }

                statusView.text = "상태: READ_STEPS 시스템 권한 화면 호출 중"
                log("[권한] permission contract launch 시작")
                permissionLauncher.launch(setOf(readPermission))
            } catch (e: ActivityNotFoundException) {
                statusView.text = "상태: Health Connect 권한 화면 없음"
                logThrowable("권한 Activity 없음", e)
                log("[권한] 'Health Connect 권한 설정 열기'를 사용하세요.")
            } catch (e: SecurityException) {
                statusView.text = "상태: Health Connect 권한 화면 보안 오류"
                logThrowable("권한 SecurityException", e)
            } catch (e: IllegalStateException) {
                statusView.text = "상태: Health Connect 서비스 상태 오류"
                logThrowable("권한 IllegalStateException", e)
            } catch (t: Throwable) {
                statusView.text = "상태: READ_STEPS 권한 요청 실패"
                logThrowable("권한 요청", t)
            }
        }
    }

    private fun openManageAccess() {
        val intents = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= 34) {
            intents += Intent(ACTION_MANAGE_HEALTH_PERMISSIONS).apply {
                putExtra(EXTRA_PACKAGE_NAME, packageName)
            }
        }

        try {
            intents += HealthConnectClient.getHealthConnectManageDataIntent(this)
        } catch (t: Throwable) {
            logThrowable("Health Connect 관리 Intent 생성", t)
        }

        intents += Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)

        val target = intents.firstOrNull { intent ->
            try {
                intent.resolveActivity(packageManager) != null
            } catch (_: Throwable) {
                false
            }
        }

        if (target == null) {
            statusView.text = "상태: Health Connect 설정 화면을 찾지 못함"
            log("[설정] 실행 가능한 Health Connect 설정 Activity 없음")
            return
        }

        try {
            startActivity(target)
            log("[설정] Health Connect 관리 화면 실행")
        } catch (t: Throwable) {
            statusView.text = "상태: Health Connect 설정 실행 실패"
            logThrowable("설정 화면 실행", t)
        }
    }

    private fun readStepsSafe() {
        if (!refreshClient()) {
            statusView.text = "상태: ${statusText()}"
            return
        }

        lifecycleScope.launch {
            try {
                val hc = client ?: return@launch
                val granted = hc.permissionController.getGrantedPermissions()
                if (!granted.contains(readPermission)) {
                    statusView.text = "상태: READ_STEPS 권한 필요"
                    log("[조회] 권한 미승인")
                    return@launch
                }

                val total = readToday(hc)
                statusView.text = "상태: 오늘 Health Connect $total 보"
                log("[조회] 오늘 합계=$total")
            } catch (t: Throwable) {
                statusView.text = "상태: 걸음 조회 실패"
                logThrowable("걸음 조회", t)
            }
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

    private fun logThrowable(action: String, t: Throwable) {
        Log.e(TAG, action, t)
        if (::logView.isInitialized) {
            log("[오류] $action: ${t.javaClass.simpleName}: ${t.message ?: "메시지 없음"}")
            t.cause?.let {
                log("[원인] ${it.javaClass.simpleName}: ${it.message ?: "메시지 없음"}")
            }
        }
    }

    private fun log(message: String) {
        if (!::logView.isInitialized) return
        Log.i(TAG, message)
        logView.append(message)
        if (!message.endsWith("\n")) logView.append("\n")
    }
}
