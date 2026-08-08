package com.example.universalstepqatool

import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class ViewPermissionUsageActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        root.addView(TextView(this).apply {
            text = "건강 데이터 사용 목적"
            textSize = 22f
        })
        root.addView(TextView(this).apply {
            text = "READ_STEPS 권한은 이 기기의 Health Connect에 저장된 오늘 걸음 수를 읽어 QA 진단 화면에 표시하기 위해서만 사용됩니다."
            textSize = 16f
            setPadding(0, 24, 0, 0)
        })
        setContentView(root)
    }
}
