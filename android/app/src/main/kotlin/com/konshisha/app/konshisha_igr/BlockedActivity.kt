package com.konshisha.app.konshisha_igr

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import android.view.Gravity
import android.graphics.Color
import android.widget.LinearLayout

class BlockedActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val reason = intent.getStringExtra("reason") ?: "Access blocked"

        val layout = LinearLayout(this)
        layout.orientation = LinearLayout.VERTICAL
        layout.gravity = Gravity.CENTER
        layout.setBackgroundColor(Color.parseColor("#212121"))

        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        params.setMargins(64, 0, 64, 0)

        val title = TextView(this)
        title.text = "ACCESS BLOCKED"
        title.setTextColor(Color.parseColor("#FF5252"))
        title.textSize = 24f
        title.gravity = Gravity.CENTER
        title.setPadding(0, 0, 0, 32)
        layout.addView(title, params)

        val message = TextView(this)
        message.text = reason
        message.setTextColor(Color.parseColor("#BDBDBD"))
        message.textSize = 16f
        message.gravity = Gravity.CENTER
        layout.addView(message, params)

        setContentView(layout)
    }

    override fun onBackPressed() {
        // Prevent back navigation
    }
}
