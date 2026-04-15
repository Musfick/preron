package com.github.musfick.preron.preron

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.app.NotificationCompat

class UssdOverlayService : Service() {

    companion object {
        private const val CHANNEL_ID    = "ussd_overlay_channel"
        private const val NOTIF_ID      = 9001
        const val ACTION_ADD_LOG        = "com.github.musfick.preron.ADD_LOG"
        const val EXTRA_LOG_TYPE        = "log_type"   // "PROMPT" or "INPUT"
        const val EXTRA_LOG_TEXT        = "log_text"
        const val ACTION_SHOW           = "com.github.musfick.preron.SHOW_OVERLAY"
        const val ACTION_HIDE           = "com.github.musfick.preron.HIDE_OVERLAY"
        const val ACTION_CLEAR          = "com.github.musfick.preron.CLEAR_OVERLAY"

        /** Called directly from UssdAccessibilityService on the main thread */
        var instance: UssdOverlayService? = null

        fun addLog(type: String, text: String) {
            instance?.appendLog(type, text)
        }
    }

    // ── Window Manager ────────────────────────────────────────────────────
    private lateinit var wm: WindowManager
    private lateinit var overlayRoot: FrameLayout
    private lateinit var logContainer: LinearLayout
    private lateinit var scrollView: ScrollView
    private lateinit var titleBar: LinearLayout
    private lateinit var badgeText: TextView
    private var logCount = 0
    private var isVisible = true

    private val handler = Handler(Looper.getMainLooper())

    // ── dp/sp helpers ─────────────────────────────────────────────────────
    private fun dp(v: Float) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics
    ).toInt()

    private fun sp(v: Float) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics
    )

    // ─────────────────────────────────────────────────────────────────────
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        buildOverlayView()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ADD_LOG -> {
                val type = intent.getStringExtra(EXTRA_LOG_TYPE) ?: "PROMPT"
                val text = intent.getStringExtra(EXTRA_LOG_TEXT) ?: ""
                appendLog(type, text)
            }
            ACTION_SHOW  -> showOverlay()
            ACTION_HIDE  -> hideOverlay()
            ACTION_CLEAR -> clearLogs()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        if (::overlayRoot.isInitialized) {
            try { wm.removeView(overlayRoot) } catch (_: Exception) {}
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Build floating overlay
    // ─────────────────────────────────────────────────────────────────────
    private fun buildOverlayView() {
        overlayRoot = FrameLayout(this)

        // ── outer card ───────────────────────────────────────────────────
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#FF121212"))
        }

        // ── title bar ────────────────────────────────────────────────────
        titleBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#1E1E1E"))
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12f), dp(8f), dp(8f), dp(8f))
        }

        val dot = View(this).apply {
            setBackgroundColor(Color.parseColor("#00E676"))
            layoutParams = LinearLayout.LayoutParams(dp(8f), dp(8f)).also {
                it.marginEnd = dp(8f)
            }
        }
        // pulse-style: we'll toggle alpha with a handler
        pulseDot(dot)

        val title = TextView(this).apply {
            text = "USSD SESSION"
            setTextColor(Color.parseColor("#B0BEC5"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            typeface = Typeface.create("monospace", Typeface.BOLD)
            letterSpacing = 0.15f
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        badgeText = TextView(this).apply {
            text = "0 events"
            setTextColor(Color.parseColor("#546E7A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.create("monospace", Typeface.NORMAL)
            setPadding(dp(0f), dp(0f), dp(8f), dp(0f))
        }

        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#78909C"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(10f), dp(6f), dp(10f), dp(6f))
            setOnClickListener { stopSelf() }
        }

        val minimizeBtn = TextView(this).apply {
            text = "—"
            setTextColor(Color.parseColor("#78909C"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(4f), dp(6f), dp(4f), dp(6f))
            setOnClickListener { toggleMinimize(card) }
        }

        titleBar.addView(dot)
        titleBar.addView(title)
        titleBar.addView(badgeText)
        titleBar.addView(minimizeBtn)
        titleBar.addView(closeBtn)

        // ── log area ─────────────────────────────────────────────────────
        scrollView = ScrollView(this).apply {
            isVerticalScrollBarEnabled = false
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f
            )
        }

        logContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4f), dp(6f), dp(4f), dp(6f))
        }

        scrollView.addView(logContainer)

        // ── bottom bar ───────────────────────────────────────────────────
        val bottomBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12f), dp(6f), dp(12f), dp(6f))
        }

        val clearBtn = TextView(this).apply {
            text = "CLEAR"
            setTextColor(Color.parseColor("#455A64"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.create("monospace", Typeface.BOLD)
            letterSpacing = 0.1f
            setOnClickListener { clearLogs() }
        }

        val bottomSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }

        val statusText = TextView(this).apply {
            text = "● LIVE"
            setTextColor(Color.parseColor("#00E676"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
            typeface = Typeface.create("monospace", Typeface.BOLD)
        }

        bottomBar.addView(clearBtn)
        bottomBar.addView(bottomSpacer)
        bottomBar.addView(statusText)

        // ── assemble ─────────────────────────────────────────────────────
        card.addView(titleBar)
        card.addView(scrollView)
        card.addView(bottomBar)
        overlayRoot.addView(card)

        // ── Window params ─────────────────────────────────────────────────
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        wm.addView(overlayRoot, params)
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Append a log row
    // ─────────────────────────────────────────────────────────────────────
    fun appendLog(type: String, text: String) {
        handler.post {
            logCount++
            badgeText.text = "$logCount events"

            val isPrompt = type.equals("PROMPT", ignoreCase = true)
            val accentColor = if (isPrompt) Color.parseColor("#FF9800") else Color.parseColor("#2196F3")
            val badgeBg     = if (isPrompt) Color.parseColor("#2A1A00") else Color.parseColor("#001A3A")

            // Row container
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(dp(6f), dp(4f), dp(6f), dp(4f))
            }

            // Badge
            val badge = TextView(this).apply {
                this.text = if (isPrompt) "◈" else "→"
                setTextColor(accentColor)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                typeface = Typeface.create("monospace", Typeface.BOLD)
                setPadding(dp(4f), dp(2f), dp(6f), dp(2f))
            }

            // Content
            val content = TextView(this).apply {
                this.text = text.trim()
                setTextColor(if (isPrompt) Color.parseColor("#CFD8DC") else Color.parseColor("#FFFFFF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10.5f)
                typeface = Typeface.create("monospace", Typeface.NORMAL)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setLineSpacing(0f, 1.4f)
            }

            // Type label
            val label = TextView(this).apply {
                this.text = if (isPrompt) "PROMPT" else "INPUT"
                setTextColor(accentColor)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 8f)
                typeface = Typeface.create("monospace", Typeface.BOLD)
                letterSpacing = 0.1f
                setBackgroundColor(badgeBg)
                setPadding(dp(4f), dp(2f), dp(4f), dp(2f))
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.marginStart = dp(4f) }
            }

            row.addView(badge)
            row.addView(content)
            row.addView(label)

            // Divider
            val divider = View(this).apply {
                setBackgroundColor(Color.parseColor("#1A2A2A"))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, dp(0.5f)
                ).also { it.setMargins(dp(8f), 0, dp(8f), 0) }
            }

            logContainer.addView(divider)
            logContainer.addView(row)

            // Auto-scroll
            scrollView.post { scrollView.fullScroll(ScrollView.FOCUS_DOWN) }

            // Re-show if minimized
            if (scrollView.visibility != View.VISIBLE) {
                scrollView.visibility = View.VISIBLE
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────

    private var isMinimized = false
    private fun toggleMinimize(card: LinearLayout) {
        isMinimized = !isMinimized
        scrollView.visibility = if (isMinimized) View.GONE else View.VISIBLE
    }

    private fun showOverlay() { overlayRoot.visibility = View.VISIBLE }
    private fun hideOverlay() { overlayRoot.visibility = View.GONE }
    private fun clearLogs() {
        handler.post {
            logContainer.removeAllViews()
            logCount = 0
            badgeText.text = "0 events"
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Dot pulse animation via Handler
    // ─────────────────────────────────────────────────────────────────────
    private fun pulseDot(dot: View) {
        val pulseRunnable = object : Runnable {
            var visible = true
            override fun run() {
                visible = !visible
                dot.alpha = if (visible) 1f else 0.2f
                handler.postDelayed(this, 800)
            }
        }
        handler.postDelayed(pulseRunnable, 800)
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Foreground notification
    // ─────────────────────────────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "USSD Overlay", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows USSD session log overlay"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("USSD Session Active")
            .setContentText("Monitoring USSD flow…")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
}