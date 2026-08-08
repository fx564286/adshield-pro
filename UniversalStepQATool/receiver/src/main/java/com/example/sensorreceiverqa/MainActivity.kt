package com.example.sensorreceiverqa

import android.app.Activity
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.util.Locale

class MainActivity : Activity() {

    companion object {
        private val SOURCE_URI = Uri.parse("content://com.example.universalstepqatool.qaaccel/sample")
        private const val POLL_MS = 120L
        private const val THRESHOLD = 1.35
        private const val REFRACTORY_NS = 280_000_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var status: TextView
    private lateinit var values: TextView
    private lateinit var logView: TextView
    private lateinit var toggle: Button

    private var running = false
    private var events = 0L
    private var detected = 0L
    private var lastSequence = -1L
    private var gravityEstimate = 9.81
    private var filteredDynamic = 0.0
    private var lastDetectedNs = 0L

    private val poller = object : Runnable {
        override fun run() {
            if (!running) return
            readOneSample()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 28, 28, 28)
        }
        root.addView(TextView(this).apply {
            text = "Sensor Receiver QA"
            textSize = 24f
            setTypeface(typeface, Typeface.BOLD)
        })
        status = TextView(this).apply {
            text = "상태: 대기"
            textSize = 17f
            setPadding(0, 18, 0, 12)
        }
        root.addView(status)

        toggle = Button(this).apply {
            text = "교차앱 가상 가속도 수신 시작"
            setOnClickListener {
                if (running) stopPolling() else startPolling()
            }
        }
        root.addView(toggle)

        root.addView(Button(this).apply {
            text = "카운터 초기화"
            setOnClickListener {
                events = 0
                detected = 0
                lastSequence = -1
                gravityEstimate = 9.81
                filteredDynamic = 0.0
                lastDetectedNs = 0L
                values.text = "값 초기화됨"
                appendLog("[초기화] 수신/감지 카운터 초기화")
            }
        })

        values = TextView(this).apply {
            text = "아직 수신된 샘플 없음"
            textSize = 16f
            setPadding(0, 22, 0, 16)
            typeface = Typeface.MONOSPACE
        }
        root.addView(values)

        root.addView(TextView(this).apply {
            text = "이 앱은 Universal Step QA Tool의 서명 보호 QA 채널만 읽습니다. Android SensorManager 값은 변경하지 않습니다."
            textSize = 14f
        })

        logView = TextView(this).apply {
            text = "실행 로그\n"
            textSize = 13f
            typeface = Typeface.MONOSPACE
            setPadding(0, 18, 0, 0)
        }
        root.addView(logView)

        setContentView(ScrollView(this).apply { addView(root) })
        appendLog("[시작] content URI=$SOURCE_URI")
    }

    private fun startPolling() {
        if (running) return
        running = true
        toggle.text = "교차앱 수신 중지"
        status.text = "상태: QA 가속도 채널 연결 중"
        handler.removeCallbacks(poller)
        handler.post(poller)
        appendLog("[수신] 시작")
    }

    private fun stopPolling() {
        running = false
        handler.removeCallbacks(poller)
        toggle.text = "교차앱 가상 가속도 수신 시작"
        status.text = "상태: 수신 중지"
        appendLog("[수신] 중지")
    }

    private fun readOneSample() {
        try {
            contentResolver.query(SOURCE_URI, null, null, null, null)?.use { c ->
                if (!c.moveToFirst()) {
                    status.text = "상태: 공급자가 빈 응답 반환"
                    return
                }
                val timestamp = c.getLong(c.getColumnIndexOrThrow("timestamp_ns"))
                val x = c.getDouble(c.getColumnIndexOrThrow("x"))
                val y = c.getDouble(c.getColumnIndexOrThrow("y"))
                val z = c.getDouble(c.getColumnIndexOrThrow("z"))
                val magnitude = c.getDouble(c.getColumnIndexOrThrow("magnitude"))
                val sequence = c.getLong(c.getColumnIndexOrThrow("sequence"))

                if (sequence != lastSequence) {
                    lastSequence = sequence
                    events++
                    processSample(magnitude, timestamp)
                }

                status.text = "상태: 교차앱 QA 가속도 수신 정상"
                values.text = buildString {
                    appendLine("x = ${"%.3f".format(Locale.US, x)} m/s²")
                    appendLine("y = ${"%.3f".format(Locale.US, y)} m/s²")
                    appendLine("z = ${"%.3f".format(Locale.US, z)} m/s²")
                    appendLine("|a| = ${"%.3f".format(Locale.US, magnitude)} m/s²")
                    appendLine("sequence = $sequence")
                    appendLine("수신 샘플 = $events")
                    append("동일 필터 걸음성 pulse 감지 = $detected")
                }
            } ?: run {
                status.text = "상태: 공급자 응답 없음"
            }
        } catch (se: SecurityException) {
            status.text = "상태: 서명 권한 불일치"
            appendLog("[권한 오류] ${se.message}")
            stopPolling()
        } catch (t: Throwable) {
            status.text = "상태: 수신 실패 (${t.javaClass.simpleName})"
            appendLog("[오류] ${t.javaClass.simpleName}: ${t.message}")
        }
    }

    private fun processSample(magnitude: Double, timestampNs: Long) {
        gravityEstimate = gravityEstimate * 0.90 + magnitude * 0.10
        val dynamic = magnitude - gravityEstimate
        filteredDynamic = filteredDynamic * 0.65 + dynamic * 0.35
        if (filteredDynamic > THRESHOLD && timestampNs - lastDetectedNs > REFRACTORY_NS) {
            detected++
            lastDetectedNs = timestampNs
            if (detected % 10L == 0L) appendLog("[감지] pulse=$detected / samples=$events")
        }
    }

    private fun appendLog(message: String) {
        logView.append(message)
        if (!message.endsWith("\n")) logView.append("\n")
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(poller)
        super.onDestroy()
    }
}
