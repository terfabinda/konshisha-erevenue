package com.konshisha.app.konshisha_igr

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class VersionProtection {
    companion object {
        private const val MIN_VERSION_KEY = "min_version_code"
        private const val PREFS_NAME = "version_protection_prefs"

        fun checkVersion(context: Context, currentVersionCode: Int): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val storedMinVersion = prefs.getInt(MIN_VERSION_KEY, 0)
            if (storedMinVersion > 0 && currentVersionCode < storedMinVersion) {
                val intent = Intent(context, BlockedActivity::class.java)
                intent.putExtra("reason", "App version downgrade detected. Please update to the latest version.")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                context.startActivity(intent)
                return false
            }
            return true
        }

        fun updateMinVersion(context: Context, versionCode: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = prefs.getInt(MIN_VERSION_KEY, 0)
            if (versionCode > current) {
                prefs.edit().putInt(MIN_VERSION_KEY, versionCode).apply()
            }
        }
    }
}
