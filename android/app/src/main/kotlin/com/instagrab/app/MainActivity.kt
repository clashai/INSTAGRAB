package com.instagrab.app

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.instagrab/clipboard"
    private val EVENT_CHANNEL = "com.instagrab/clipboard_events"
    private val SERVICE_CHANNEL = "com.instagrab/service"
    private val ACCESSIBILITY_CHANNEL = "com.instagrab/accessibility"

    private var clipboardManager: ClipboardManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var lastClip: String = ""
    private var pendingSharedText: String? = null

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        val clip = clipboardManager?.primaryClip
        if (clip != null && clip.itemCount > 0) {
            val text = clip.getItemAt(0).text?.toString() ?: ""
            if (text != lastClip && text.isNotBlank()) {
                lastClip = text
                eventSink?.success(text)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getClipboard" -> {
                    val clip = clipboardManager?.primaryClip
                    if (clip != null && clip.itemCount > 0) {
                        result.success(clip.getItemAt(0).text?.toString())
                    } else {
                        result.success(null)
                    }
                }
                "getPendingShare" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    clipboardManager?.addPrimaryClipChangedListener(clipListener)
                    pendingSharedText?.let { text ->
                        events?.success(text)
                        pendingSharedText = null
                    }
                }
                override fun onCancel(arguments: Any?) {
                    clipboardManager?.removePrimaryClipChangedListener(clipListener)
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, ClipboardService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    stopService(Intent(this, ClipboardService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openSettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "getPendingUrl" -> {
                    val prefs = getSharedPreferences(ClipboardCaptureActivity.PREFS_NAME, Context.MODE_PRIVATE)
                    val url = prefs.getString(ClipboardCaptureActivity.KEY_PENDING_URL, null)
                    if (!url.isNullOrBlank()) {
                        prefs.edit().remove(ClipboardCaptureActivity.KEY_PENDING_URL).apply()
                    }
                    result.success(url)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        checkPendingAccessibilityUrl()
    }

    private fun checkPendingAccessibilityUrl() {
        try {
            val prefs = getSharedPreferences(ClipboardCaptureActivity.PREFS_NAME, Context.MODE_PRIVATE)
            val pendingUrl = prefs.getString(ClipboardCaptureActivity.KEY_PENDING_URL, null)
            if (!pendingUrl.isNullOrBlank()) {
                prefs.edit().remove(ClipboardCaptureActivity.KEY_PENDING_URL).apply()
                sendUrlToFlutter(pendingUrl)
            }
        } catch (_: Exception) {}
    }

    private fun sendUrlToFlutter(url: String) {
        if (eventSink != null) {
            eventSink?.success(url)
        } else {
            pendingSharedText = url
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_GENERIC)
        for (service in enabledServices) {
            val id = service.resolveInfo.serviceInfo
            if (id.packageName == packageName && id.name == InstaGrabAccessibilityService::class.java.name) {
                return true
            }
        }
        return false
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (sharedText != null) {
                        sendUrlToFlutter(sharedText)
                    }
                }
            }
            "com.instagrab.DOWNLOAD" -> {
                val url = intent.getStringExtra("instagram_url")
                if (url != null) {
                    sendUrlToFlutter(url)
                }
            }
            "com.instagrab.CHECK_CLIPBOARD" -> {
                // Legacy fallback — read clipboard now that we're in foreground
                val clip = clipboardManager?.primaryClip
                if (clip != null && clip.itemCount > 0) {
                    val text = clip.getItemAt(0).text?.toString() ?: ""
                    if (text.isNotBlank()) {
                        sendUrlToFlutter(text)
                    }
                }
            }
        }
    }
}
