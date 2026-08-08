package com.example.universalstepqatool

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class PermissionsRationaleActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        root.addView(TextView(this).apply {
            text = "Health Connect 걸음 읽기 권한 안내"
            textSize = 22f
        })
        root.addView(TextView(this).apply {
            text = "이 QA 도구는 사용자가 허용한 경우에만 Health Connect의 오늘 걸음 합계를 읽어 센서/건강 데이터 연동 상태를 진단합니다. 이 화면에서는 걸음 데이터를 기록하거나 수정하지 않습니다."
            textSize = 16f
            setPadding(0, 24, 0, 0)
        })
        setContentView(root)
    }
}
