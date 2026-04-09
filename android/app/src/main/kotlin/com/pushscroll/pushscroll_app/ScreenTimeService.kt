package com.pushscroll.pushscroll_app

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.*
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.*

class ScreenTimeService : Service() {

    companion object {
        const val CHANNEL_ID = "repscreen_timer"
        const val NOTIFICATION_ID = 1001
    }

    private var remainingSeconds = 0
    private var blockedPackages = listOf<String>()
    private var timer: Timer? = null
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var isOverlayShowing = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                remainingSeconds = intent.getIntExtra("seconds", 0)
                blockedPackages =
                    intent.getStringArrayListExtra("blocked") ?: listOf()
                startForeground(NOTIFICATION_ID, buildNotification())
                startTimer()
            }
            "STOP" -> {
                stopTimer()
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    /* â”€â”€ notification channel â”€â”€ */

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Screen Time Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows remaining screen time"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val mins = remainingSeconds / 60
        val secs = remainingSeconds % 60
        val text =
            if (remainingSeconds > 0) String.format("Screen time: %d:%02d remaining", mins, secs)
            else "Screen time is up! Exercise to earn more."

        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RepScreen")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setContentIntent(pi)
            .setSilent(true)
            .build()
    }

    /* â”€â”€ timer â”€â”€ */

    private fun startTimer() {
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (remainingSeconds > 0) {
                    remainingSeconds--
                    updateNotification()
                }
                if (remainingSeconds <= 0 && blockedPackages.isNotEmpty()) {
                    checkForegroundApp()
                }
            }
        }, 1000, 1000)
    }

    private fun stopTimer() {
        timer?.cancel()
        timer = null
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification())
    }

    /* â”€â”€ foreground-app check â”€â”€ */

    private fun checkForegroundApp() {
        try {
            val usm =
                getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, now - 10_000, now
            )
            if (stats != null && stats.isNotEmpty()) {
                val current = stats.maxByOrNull { it.lastTimeUsed }?.packageName
                if (current != null && blockedPackages.contains(current)) {
                    handler.post { showOverlay() }
                } else {
                    handler.post { hideOverlay() }
                }
            }
        } catch (_: Exception) {
            // permission may not be granted
        }
    }

    /* â”€â”€ overlay â”€â”€ */

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, value.toFloat(),
            resources.displayMetrics
        ).toInt()

    private fun showOverlay() {
        if (isOverlayShowing || !Settings.canDrawOverlays(this)) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#F2080818"))
            setPadding(dp(40), dp(60), dp(40), dp(60))
        }

        val emoji = TextView(this).apply {
            text = "\u23F0"
            textSize = 56f
            gravity = Gravity.CENTER
        }

        val title = TextView(this).apply {
            text = "Screen Time\u2019s Up!"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, dp(10))
            typeface = Typeface.DEFAULT_BOLD
        }

        val sub = TextView(this).apply {
            text = "Do some reps to earn more screen time!"
            textSize = 15f
            setTextColor(Color.parseColor("#99FFFFFF"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(36))
        }

        val btn = TextView(this).apply {
            text = "\uD83D\uDCAA  Exercise Now"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(16), dp(32), dp(16))
            setBackgroundColor(Color.parseColor("#6C63FF"))
            setOnClickListener {
                startActivity(
                    Intent(this@ScreenTimeService, MainActivity::class.java).apply {
                        flags =
                            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                )
                hideOverlay()
            }
        }

        root.addView(emoji)
        root.addView(title)
        root.addView(sub)
        root.addView(btn)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager?.addView(root, params)
            overlayView = root
            isOverlayShowing = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay() {
        if (!isOverlayShowing || overlayView == null) return
        try { windowManager?.removeView(overlayView) } catch (_: Exception) {}
        overlayView = null
        isOverlayShowing = false
    }

    override fun onDestroy() {
        stopTimer()
        hideOverlay()
        super.onDestroy()
    }
}