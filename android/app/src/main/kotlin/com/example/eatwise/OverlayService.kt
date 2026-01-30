package com.example.eatwise

import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import android.graphics.drawable.GradientDrawable

/**
 * Foreground service that displays a floating overlay button
 */
class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "eatwise_overlay_channel"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            context.stopService(intent)
        }
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        showOverlay()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "EatWise Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the ingredient scanner active"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // Create intent to open app when notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EatWise Active")
            .setContentText("Tap the floating icon to scan ingredients")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun showOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 50
        params.y = 400

        // Create floating button with custom styling
        overlayView = createFloatingButton()

        // Make it draggable and clickable
        setupTouchListener(overlayView!!, params)

        windowManager.addView(overlayView, params)
    }

    private fun createFloatingButton(): ImageView {
        return ImageView(this).apply {
            // Try to use app launcher icon, fallback to search icon
            try {
                setImageResource(R.mipmap.ic_launcher)
                // No color filter for the logo
                colorFilter = null
                scaleType = ImageView.ScaleType.CENTER_INSIDE
            } catch (e: Exception) {
                setImageResource(android.R.drawable.ic_menu_search)
                setColorFilter(0xFFFFFFFF.toInt())
            }
            
            // Create circular white background with green border
            val shape = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFFFFFFF.toInt()) // White background
                setStroke(4, 0xFF4CAF50.toInt()) // Green border
            }
            background = shape
            
            // Set padding and size
            val size = (60 * resources.displayMetrics.density).toInt()
            minimumWidth = size
            minimumHeight = size
            
            val padding = (8 * resources.displayMetrics.density).toInt()
            setPadding(padding, padding, padding, padding)
            
            // Elevation for shadow
            elevation = 12f
        }
    }

    private fun setupTouchListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = true
        var touchStartTime = 0L

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    touchStartTime = System.currentTimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY

                    // If moved more than threshold, it's a drag not a click
                    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                        isClick = false
                    }

                    params.x = initialX + deltaX.toInt()
                    params.y = initialY + deltaY.toInt()
                    windowManager.updateViewLayout(overlayView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val touchDuration = System.currentTimeMillis() - touchStartTime
                    
                    // Consider it a click if:
                    // 1. Didn't move much AND
                    // 2. Touch was short (< 300ms)
                    if (isClick && touchDuration < 300) {
                        // Trigger ingredient scan
                        IngredientScanner.start(this)
                        
                        // Visual feedback - pulse animation
                        view.animate()
                            .scaleX(1.2f)
                            .scaleY(1.2f)
                            .setDuration(100)
                            .withEndAction {
                                view.animate()
                                    .scaleX(1f)
                                    .scaleY(1f)
                                    .setDuration(100)
                                    .start()
                            }
                            .start()
                    }
                    true
                }
                else -> false
            }
        }
    }

    override fun onDestroy() {
        overlayView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                // View might already be removed
            }
        }
        overlayView = null
        super.onDestroy()
    }
}
