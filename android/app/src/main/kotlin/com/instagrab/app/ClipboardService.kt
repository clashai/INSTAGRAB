package com.instagrab.app

import android.app.*
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ClipboardService : Service() {

    companion object {
        const val CHANNEL_ID = "instagrab_clipboard"
        const val NOTIFICATION_ID = 1001
    }

    private var clipboardManager: ClipboardManager? = null
    private var lastClip: String = ""

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        val clip = clipboardManager?.primaryClip
        if (clip != null && clip.itemCount > 0) {
            val text = clip.getItemAt(0).text?.toString() ?: ""
            if (text != lastClip && text.isNotBlank() && isInstagramUrl(text)) {
                lastClip = text
                showDownloadNotification(text)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildForegroundNotification()
        startForeground(NOTIFICATION_ID, notification)
        clipboardManager?.addPrimaryClipChangedListener(clipListener)
        return START_STICKY
    }

    override fun onDestroy() {
        clipboardManager?.removePrimaryClipChangedListener(clipListener)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "InstaGrab Clipboard Watcher",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors clipboard for Instagram links"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("InstaGrab Active")
            .setContentText("Watching clipboard for Instagram links")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showDownloadNotification(url: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("download_url", url)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 1, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Instagram link detected!")
            .setContentText("Tap to download: $url")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(url.hashCode(), notification)
    }

    private fun isInstagramUrl(text: String): Boolean {
        return text.contains("instagram.com/reel") ||
                text.contains("instagram.com/p/") ||
                text.contains("instagram.com/tv/") ||
                text.contains("instagr.am/")
    }
}
