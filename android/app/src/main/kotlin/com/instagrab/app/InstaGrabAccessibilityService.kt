package com.instagrab.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class InstaGrabAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "InstaGrabA11y"
        private var lastTriggerTime = 0L
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.e(TAG, "Accessibility service connected")

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return

        val pkg = event.packageName?.toString() ?: ""

        // Only log events from Instagram to reduce noise
        if (pkg.contains("instagram")) {
            val text = event.text?.joinToString(" ") ?: ""
            val desc = event.contentDescription?.toString() ?: ""
            Log.d(TAG, "IG event: type=${event.eventType} class=${event.className} " +
                    "text='$text' desc='$desc' changes=${event.contentChangeTypes}")
        }

        when (event.eventType) {
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                val text = event.text?.joinToString(" ") ?: ""
                val lowerText = text.lowercase()
                if (lowerText.contains("copied") || lowerText.contains("clipboard") ||
                    lowerText.contains("link")) {
                    Log.d(TAG, "Copy detected via notification: $text")
                    launchClipboardCapture()
                }
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (event.contentChangeTypes and 0x00000080 != 0) {
                    Log.d(TAG, "Clipboard change via content change type")
                    launchClipboardCapture()
                }
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                val text = event.text?.joinToString(" ") ?: ""
                if (text.contains("instagram.com")) {
                    Log.d(TAG, "Instagram URL in text change")
                    launchClipboardCapture()
                }
            }
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val className = event.className?.toString() ?: ""
                val text = event.text?.joinToString(" ")?.lowercase() ?: ""
                if (text.contains("copied") || text.contains("clipboard") ||
                    className.contains("Toast") || className.contains("Clipboard")) {
                    Log.d(TAG, "Clipboard toast/window detected")
                    launchClipboardCapture()
                }
            }
            // Also detect "Copy Link" button clicks in Instagram
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                if (pkg.contains("instagram")) {
                    val text = event.text?.joinToString(" ")?.lowercase() ?: ""
                    val desc = event.contentDescription?.toString()?.lowercase() ?: ""
                    if (text.contains("copy") || desc.contains("copy") ||
                        text.contains("link") || desc.contains("link")) {
                        Log.d(TAG, "Instagram copy/link button clicked: text='$text' desc='$desc'")
                        handler.postDelayed({ launchClipboardCapture() }, 500)
                    }
                }
            }
        }
    }

    private fun launchClipboardCapture() {
        val now = System.currentTimeMillis()
        if (now - lastTriggerTime < 2000) return
        lastTriggerTime = now

        Log.e(TAG, "=== TRIGGER: launching ClipboardCaptureActivity ===")
        handler.postDelayed({
            try {
                val intent = Intent(this, ClipboardCaptureActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                startActivity(intent)
                Log.e(TAG, "ClipboardCaptureActivity started successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch ClipboardCaptureActivity", e)
            }
        }, 150)
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted")
    }

    override fun onDestroy() {
        Log.i(TAG, "Accessibility service destroyed")
        super.onDestroy()
    }
}
