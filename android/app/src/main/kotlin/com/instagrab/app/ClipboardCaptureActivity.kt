package com.instagrab.app

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.util.Log

class ClipboardCaptureActivity : Activity() {

    companion object {
        private const val TAG = "InstaGrabClipCapture"
        const val PREFS_NAME = "instagrab_clipboard"
        const val KEY_PENDING_URL = "pending_url"
        const val KEY_TIMESTAMP = "timestamp"

        private val instagramPattern = Regex(
            """(https?://)?(www\.)?instagram\.com/(reel|p|tv|reels)/[A-Za-z0-9_-]+"""
        )
        private val shortPattern = Regex(
            """(https?://)?instagr\.am/[A-Za-z0-9_-]+"""
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readClipboardAndStore()
    }

    private fun readClipboardAndStore() {
        Log.e(TAG, "ClipboardCaptureActivity created, scheduling read")
        window.decorView.postDelayed({
            Log.e(TAG, "Reading clipboard now...")
            try {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = cm.primaryClip
                Log.e(TAG, "Clipboard clip: items=${clip?.itemCount ?: 0}")
                if (clip != null && clip.itemCount > 0) {
                    val text = clip.getItemAt(0).text?.toString() ?: ""
                    Log.e(TAG, "Clipboard text: '${text.take(100)}'")

                    val url = extractInstagramUrl(text)
                    if (url != null) {
                        Log.e(TAG, "Instagram URL found, storing: $url")
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString(KEY_PENDING_URL, url)
                            .putLong(KEY_TIMESTAMP, System.currentTimeMillis())
                            .apply()
                    } else {
                        Log.e(TAG, "No Instagram URL in clipboard text")
                    }
                } else {
                    Log.e(TAG, "Clipboard is empty or null")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read clipboard", e)
            }
            finish()
            overridePendingTransition(0, 0)
        }, 150)
    }

    private fun extractInstagramUrl(text: String): String? {
        val match = instagramPattern.find(text) ?: shortPattern.find(text) ?: return null
        var url = match.value
        if (!url.startsWith("http")) url = "https://$url"
        return url
    }
}
