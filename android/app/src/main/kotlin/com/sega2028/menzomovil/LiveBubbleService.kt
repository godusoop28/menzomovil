package com.sega2028.menzomovil

import android.animation.ValueAnimator
import android.app.Service
import android.content.Intent
import android.content.res.Resources
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout

/**
 * Burbuja flotante estilo Messenger para el LIVE de voz — visible sobre otras apps cuando Menzo
 * pasa a segundo plano durante un LIVE. Es puramente una vista + manejo de gestos: no inicializa
 * Agora, no toca `BackgroundAudioService`, no decide el estado del micrófono. Solo refleja lo
 * que Dart le manda por `ACTION_SHOW`/`ACTION_UPDATE` y reporta toques del usuario de vuelta a
 * Dart vía [LiveBubbleBridge] (que a su vez los reenvía al único estado real: `liveProvider`).
 *
 * Requiere `Settings.canDrawOverlays` ya concedido — quien llama a `ACTION_SHOW` (Dart, vía
 * `live_bubble_channel.dart`) ya lo verificó antes de arrancar el servicio.
 */
class LiveBubbleService : Service() {
    companion object {
        const val ACTION_SHOW = "show"
        const val ACTION_UPDATE = "update"
        const val ACTION_HIDE = "hide"
        const val EXTRA_CAN_SPEAK = "canSpeak"
        const val EXTRA_MUTED = "muted"
        private const val TAP_MAX_MOVE_PX = 12
        private const val TAP_MAX_MILLIS = 250
        private const val EXPANDED_AUTO_COLLAPSE_MS = 4000L
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var micDot: View? = null
    private var expandedRow: LinearLayout? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var canSpeak = false
    private var muted = true
    private var expanded = false
    private val collapseRunnable = Runnable { setExpanded(false) }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                canSpeak = intent.getBooleanExtra(EXTRA_CAN_SPEAK, false)
                muted = intent.getBooleanExtra(EXTRA_MUTED, true)
                showBubble()
            }
            ACTION_UPDATE -> {
                canSpeak = intent.getBooleanExtra(EXTRA_CAN_SPEAK, canSpeak)
                muted = intent.getBooleanExtra(EXTRA_MUTED, muted)
                updateMicVisual()
            }
            ACTION_HIDE -> {
                removeBubble()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun dp(value: Int): Int {
        val density = Resources.getSystem().displayMetrics.density
        return (value * density).toInt()
    }

    private fun showBubble() {
        if (bubbleView != null) {
            updateMicVisual()
            return
        }
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val size = dp(56)
        val container = FrameLayout(this)

        val circle = ImageView(this)
        circle.setImageResource(R.mipmap.ic_launcher)
        circle.scaleType = ImageView.ScaleType.CENTER_CROP
        val ring = GradientDrawable()
        ring.shape = GradientDrawable.OVAL
        ring.setStroke(dp(2), Color.parseColor("#FF7A45"))
        circle.background = ring
        circle.setPadding(dp(2), dp(2), dp(2), dp(2))
        container.addView(circle, FrameLayout.LayoutParams(size, size))

        val dot = View(this)
        val dotDrawable = GradientDrawable()
        dotDrawable.shape = GradientDrawable.OVAL
        dotDrawable.setColor(Color.parseColor("#FF5A5F"))
        dot.background = dotDrawable
        val dotSize = dp(14)
        val dotParams = FrameLayout.LayoutParams(dotSize, dotSize, Gravity.BOTTOM or Gravity.END)
        container.addView(dot, dotParams)
        micDot = dot

        val expandedContainer = LinearLayout(this)
        expandedContainer.orientation = LinearLayout.HORIZONTAL
        expandedContainer.visibility = View.GONE
        expandedContainer.setPadding(dp(8), dp(4), dp(8), dp(4))
        val expandedBg = GradientDrawable()
        expandedBg.shape = GradientDrawable.RECTANGLE
        expandedBg.cornerRadius = dp(20).toFloat()
        expandedBg.setColor(Color.parseColor("#E6141821"))
        expandedContainer.background = expandedBg
        expandedRow = expandedContainer

        if (canSpeak) {
            val micBtn = simpleActionView("🎤")
            micBtn.setOnClickListener {
                LiveBubbleBridge.emit("toggle_mute")
            }
            expandedContainer.addView(micBtn)
        }
        val leaveBtn = simpleActionView("✕")
        leaveBtn.setOnClickListener {
            LiveBubbleBridge.emit("leave")
            removeBubble()
            stopSelf()
        }
        expandedContainer.addView(leaveBtn)

        val root = FrameLayout(this)
        root.addView(
            expandedContainer,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER_VERTICAL or Gravity.START,
            ),
        )
        val bubbleParams = FrameLayout.LayoutParams(size, size, Gravity.CENTER_VERTICAL or Gravity.END)
        root.addView(container, bubbleParams)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP or Gravity.START
        val metrics: DisplayMetrics = Resources.getSystem().displayMetrics
        params.x = metrics.widthPixels - size - dp(8)
        params.y = metrics.heightPixels / 3
        layoutParams = params

        attachTouchHandling(container, root, params, wm)

        wm.addView(root, params)
        bubbleView = root
        updateMicVisual()
    }

    private fun simpleActionView(glyph: String): android.widget.TextView {
        val tv = android.widget.TextView(this)
        tv.text = glyph
        tv.textSize = 16f
        tv.setTextColor(Color.WHITE)
        tv.gravity = Gravity.CENTER
        tv.setPadding(dp(10), dp(6), dp(10), dp(6))
        return tv
    }

    private fun attachTouchHandling(
        handle: View,
        root: View,
        params: WindowManager.LayoutParams,
        wm: WindowManager,
    ) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var downTime = 0L

        val gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onLongPress(e: MotionEvent) {
                setExpanded(!expanded)
            }
        })

        handle.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    downTime = System.currentTimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX - (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    wm.updateViewLayout(root, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val movedX = Math.abs(event.rawX - initialTouchX)
                    val movedY = Math.abs(event.rawY - initialTouchY)
                    val elapsed = System.currentTimeMillis() - downTime
                    if (movedX < TAP_MAX_MOVE_PX && movedY < TAP_MAX_MOVE_PX && elapsed < TAP_MAX_MILLIS) {
                        openApp()
                    } else {
                        snapToEdge(root, params, wm)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun snapToEdge(root: View, params: WindowManager.LayoutParams, wm: WindowManager) {
        val metrics = Resources.getSystem().displayMetrics
        val bubbleWidth = root.width.takeIf { it > 0 } ?: dp(56)
        val screenMid = metrics.widthPixels / 2
        val targetX = if (params.x + bubbleWidth / 2 < screenMid) {
            dp(8)
        } else {
            metrics.widthPixels - bubbleWidth - dp(8)
        }
        val animator = ValueAnimator.ofInt(params.x, targetX)
        animator.duration = 180
        animator.addUpdateListener { animation ->
            params.x = animation.animatedValue as Int
            try {
                wm.updateViewLayout(root, params)
            } catch (_: Exception) {
                // La vista puede haber sido removida (el usuario abandonó el LIVE) mientras
                // la animación seguía corriendo — no es un error real, solo dejamos de animar.
                animation.cancel()
            }
        }
        animator.start()
    }

    private fun setExpanded(value: Boolean) {
        expanded = value
        expandedRow?.visibility = if (value) View.VISIBLE else View.GONE
        expandedRow?.removeCallbacks(collapseRunnable)
        if (value) {
            expandedRow?.postDelayed(collapseRunnable, EXPANDED_AUTO_COLLAPSE_MS)
        }
    }

    private fun updateMicVisual() {
        val dot = micDot ?: return
        val color = if (!canSpeak) {
            Color.parseColor("#3DB8FF") // audiencia: celeste, sin control de mic
        } else if (muted) {
            Color.parseColor("#FF5A5F") // hablante silenciado
        } else {
            Color.parseColor("#34C77B") // hablante activo
        }
        (dot.background as? GradientDrawable)?.setColor(color)
    }

    private fun openApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        launchIntent?.let { startActivity(it) }
        LiveBubbleBridge.emit("open")
    }

    private fun removeBubble() {
        val view = bubbleView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
            // Ya no estaba adjunta — nada que hacer.
        }
        bubbleView = null
        micDot = null
        expandedRow = null
        layoutParams = null
    }

    override fun onDestroy() {
        removeBubble()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
