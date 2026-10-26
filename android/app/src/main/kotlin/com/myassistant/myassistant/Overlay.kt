package com.myassistant.myassistant

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale
import kotlin.math.abs

/**
 * THE ASSISTANT OVER OTHER APPS (2026-10-19, owner).
 *
 *  • The reply pop-up: "Ravi: are you coming at 7?" — it listens at once
 *    (his choice), shows what it heard, and sends it after 3 seconds unless
 *    Cancel is tapped (his choice). "No", "skip", "leave it" dismisses.
 *  • The inform pop-up: one line ("Swiggy order arriving in 5 minutes"),
 *    gone by itself after 8 seconds; says so when it was kept in memory.
 *  • The floating mic: the app's orb, small, draggable; a tap opens the
 *    assistant straight into a conversation. Hidden while the app itself is
 *    on screen. Still, except on the owner's turn: then a green border
 *    runs round it and "Speak now" shows beside it (2026-10-26).
 * Drawn natively so it works with the app closed. One pop-up at a time.
 */
@SuppressLint("StaticFieldLeak")
object Overlay {
    private const val TAG = "HariOverlay"
    const val EXTRA_TALK = "hari_talk"
    private val main = Handler(Looper.getMainLooper())

    private var wm: WindowManager? = null
    private var app: Context? = null

    // ── the floating mic ─────────────────────────────────────────────────
    private var bubble: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var bubbleSize = 0
    // "Speak now" beside the bubble while it is the owner's turn.
    private var label: TextView? = null
    private var labelParams: WindowManager.LayoutParams? = null
    private var labelWanted = false
    @Volatile var appVisible = false
        private set

    fun setAppVisible(ctx: Context, visible: Boolean) {
        appVisible = visible
        main.post {
            if (visible) bubble?.visibility = View.GONE
            else if (NotifyPrefs.bubbleOn(ctx)) { if (bubble == null) showBubble(ctx) else bubble?.visibility = View.VISIBLE }
            syncLabel(ctx)
        }
    }

    private fun wm(ctx: Context): WindowManager {
        app = ctx.applicationContext
        return wm ?: (ctx.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager).also { wm = it }
    }

    private fun dp(ctx: Context, v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, ctx.resources.displayMetrics)

    private fun overlayParams(w: Int, h: Int, focusable: Boolean = false) = WindowManager.LayoutParams(
        w, h,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        (if (focusable) 0 else WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE) or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    )

    @SuppressLint("ClickableViewAccessibility")
    fun showBubble(ctx: Context) {
        if (!Settings.canDrawOverlays(ctx)) return
        if (bubble != null) { if (!appVisible) bubble?.visibility = View.VISIBLE; return }
        // The orb (58 dp, as before) with room round it for its border of
        // light (OrbView.BODY): that room is its margin from the screen edge.
        val size = dp(ctx, 74f).toInt()
        val orb = OrbView(ctx.applicationContext, halo = true)
        orb.contentDescription = "Talk to the assistant"
        val lp = overlayParams(size, size).apply {
            gravity = Gravity.TOP or Gravity.START
            x = ctx.resources.displayMetrics.widthPixels - size - dp(ctx, 2f).toInt()
            y = (ctx.resources.displayMetrics.heightPixels * 0.62f).toInt()
        }
        var downX = 0f; var downY = 0f; var startX = 0; var startY = 0; var moved = false
        orb.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; moved = false; true }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    if (abs(dx) > 12 || abs(dy) > 12) moved = true
                    if (moved) { lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt(); try { wm(ctx).updateViewLayout(orb, lp) } catch (_: Throwable) {}; syncLabel(ctx) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) talk(ctx)
                    else {
                        // Rest against the nearer edge.
                        val wpx = ctx.resources.displayMetrics.widthPixels
                        lp.x = if (lp.x + size / 2 < wpx / 2) 0 else wpx - size
                        try { wm(ctx).updateViewLayout(orb, lp) } catch (_: Throwable) {}
                        syncLabel(ctx)
                    }
                    true
                }
                else -> false
            }
        }
        try {
            wm(ctx).addView(orb, lp)
            bubble = orb; bubbleParams = lp; bubbleSize = size
            if (appVisible) orb.visibility = View.GONE
        } catch (t: Throwable) { Log.w(TAG, "bubble: ${t.javaClass.simpleName}") }
    }

    fun hideBubble() {
        labelWanted = false
        val l = label
        label = null; labelParams = null
        val b = bubble ?: run { if (l != null) main.post { try { wm?.removeView(l) } catch (_: Throwable) {} }; return }
        bubble = null
        main.post {
            if (l != null) try { wm?.removeView(l) } catch (_: Throwable) {}
            try { wm?.removeView(b) } catch (_: Throwable) {}
        }
    }

    /** "Speak now" beside the bubble, on the side away from the screen edge — or hidden. */
    private fun syncLabel(ctx: Context) {
        val b = bubble; val blp = bubbleParams
        if (!labelWanted || b == null || blp == null || appVisible || b.visibility != View.VISIBLE) {
            if (labelWanted && label?.visibility != View.GONE) {
                Log.i(TAG, "speak-now held back: bubble=${b != null} appVisible=$appVisible shown=${b?.visibility == View.VISIBLE}")
            }
            label?.visibility = View.GONE
            return
        }
        val c = ctx.applicationContext
        val h = dp(c, 28f).toInt()
        val tv = label ?: TextView(c).apply {
            text = "Speak now"
            setTextColor(Color.WHITE); textSize = 12.5f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER; maxLines = 1
            val p = dp(c, 12f).toInt()
            setPadding(p, 0, p, 0)
            // Green, as the border on the owner's turn.
            background = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(Color.parseColor("#F21DB866"), Color.parseColor("#F20E8F4E"))).apply {
                cornerRadius = h / 2f
                setStroke(dp(c, 1.2f).toInt(), Color.parseColor("#CCB6FFD6"))
            }
            elevation = dp(c, 4f)
            visibility = View.GONE
        }
        // Touches pass through it to the app underneath.
        val lp = labelParams ?: overlayParams(WindowManager.LayoutParams.WRAP_CONTENT, h).apply {
            flags = flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        val wpx = c.resources.displayMetrics.widthPixels
        val onLeft = blp.x + bubbleSize / 2 < wpx / 2
        lp.gravity = Gravity.TOP or (if (onLeft) Gravity.START else Gravity.END)
        lp.x = if (onLeft) blp.x + bubbleSize else wpx - blp.x
        lp.y = blp.y + (bubbleSize - h) / 2
        try {
            if (label == null) { wm(c).addView(tv, lp); label = tv; labelParams = lp }
            else wm(c).updateViewLayout(tv, lp)
            if (tv.visibility != View.VISIBLE) {
                Log.i(TAG, "speak-now shown")
                tv.alpha = 0f; tv.visibility = View.VISIBLE
                tv.animate().alpha(1f).setDuration(180).start()
            }
        } catch (t: Throwable) { Log.w(TAG, "label: ${t.javaClass.simpleName}") }
    }

    /**
     * The running app's channel (MainActivity sets it; null once its engine
     * is gone). A bubble tap goes through it so the conversation happens
     * right here, over the other app (owner: "don't open the app").
     */
    @Volatile var dart: io.flutter.plugin.common.MethodChannel? = null

    /**
     * The bubble breathes faster while a conversation from it is live, and
     * ripples with "Speak now" beside it while it is the owner's turn
     * ([userTurn]: the microphone open for him — when the voice screen
     * says "Listening…").
     */
    fun setBubbleActive(active: Boolean, userTurn: Boolean = false) {
        Log.i(TAG, "bubble state: active=$active userTurn=$userTurn")
        main.post {
            (bubble as? OrbView)?.let { it.listening = active; it.userTurn = active && userTurn }
            labelWanted = active && userTurn
            app?.let { syncLabel(it) }
        }
    }

    /** The bubble's tap: talk in place; open the app only if it is not running. */
    private fun talk(ctx: Context) {
        val ch = dart
        if (ch == null) { openApp(ctx); return }
        // The microphone service first, while the bubble is on screen —
        // Android allows it then; the conversation opens the mic shortly.
        MicService.acquire(ctx, "bubble")
        try {
            ch.invokeMethod("bubbleTap", null, object : io.flutter.plugin.common.MethodChannel.Result {
                override fun success(r: Any?) {
                    when (r) {
                        "started" -> {}
                        "unavailable" -> { MicService.release(ctx, "bubble"); openApp(ctx) }
                        else -> MicService.release(ctx, "bubble")
                    }
                }
                override fun error(code: String, msg: String?, details: Any?) {
                    MicService.release(ctx, "bubble"); openApp(ctx)
                }
                override fun notImplemented() { MicService.release(ctx, "bubble"); openApp(ctx) }
            })
        } catch (t: Throwable) {
            Log.w(TAG, "bubble talk: ${t.javaClass.simpleName}")
            MicService.release(ctx, "bubble"); openApp(ctx)
        }
    }

    /** No running app to talk through: open it straight into a conversation. */
    private fun openApp(ctx: Context) {
        val i = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            .putExtra(EXTRA_TALK, true)
        try { ctx.startActivity(i) } catch (t: Throwable) { Log.w(TAG, "talk: ${t.javaClass.simpleName}") }
    }

    // ── the pop-up card ──────────────────────────────────────────────────
    private var card: View? = null
    private var status: TextView? = null
    private var leftBtn: TextView? = null
    private var rightBtn: TextView? = null
    private var orbSmall: OrbView? = null
    private var recognizer: SpeechRecognizer? = null
    private var pendingSend: Runnable? = null
    private var autoHide: Runnable? = null
    private var busy = false // listening or counting down: nothing replaces it

    fun showInfo(ctx: Context, appName: String, say: String, remembered: Boolean) {
        if (busy) return
        build(ctx, appName, say)
        status?.text = if (remembered) "Saved to your memory" else ""
        status?.visibility = if (remembered) View.VISIBLE else View.GONE
        button(leftBtn, "Dismiss") { dismiss(ctx) }
        rightBtn?.visibility = View.GONE
        hideIn(ctx, 8000)
    }

    fun showReply(ctx: Context, appName: String, say: String, action: Notification.Action) {
        if (busy) return
        build(ctx, appName, say)
        button(leftBtn, "Dismiss") { dismiss(ctx) }
        button(rightBtn, "Reply") { listen(ctx, action) }
        // His choice: listen straight away.
        main.postDelayed({ if (card != null && !busy) listen(ctx, action) }, 500)
    }

    private fun build(ctx: Context, appName: String, say: String) {
        dismissNow()
        val c = ctx.applicationContext
        val pad = dp(c, 16f).toInt()
        val box = LinearLayout(c).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, dp(c, 14f).toInt(), pad, dp(c, 10f).toInt())
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.parseColor("#F21C1640"), Color.parseColor("#F2120E2A"))).apply {
                cornerRadius = dp(c, 24f)
                setStroke(dp(c, 1.2f).toInt(), Color.parseColor("#998B5CFF"))
            }
            elevation = dp(c, 12f)
        }
        val head = LinearLayout(c).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        val orb = OrbView(c, showMic = false)
        head.addView(orb, LinearLayout.LayoutParams(dp(c, 22f).toInt(), dp(c, 22f).toInt()))
        head.addView(TextView(c).apply {
            text = appName
            setTextColor(Color.parseColor("#B9B3E6")); textSize = 12.5f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(c, 8f).toInt(), 0, 0, 0)
            maxLines = 1; ellipsize = TextUtils.TruncateAt.END
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(head)
        box.addView(TextView(c).apply {
            text = say
            setTextColor(Color.WHITE); textSize = 15.5f
            maxLines = 4; ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(c, 8f).toInt(), 0, 0)
        })
        val st = TextView(c).apply {
            setTextColor(Color.parseColor("#D7C8FF")); textSize = 13.5f
            setPadding(0, dp(c, 8f).toInt(), 0, 0); maxLines = 3
        }
        box.addView(st)
        val row = LinearLayout(c).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.END; setPadding(0, dp(c, 8f).toInt(), 0, 0) }
        val l = pill(c, false); val r = pill(c, true)
        row.addView(l); row.addView(r, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { leftMargin = dp(c, 8f).toInt() })
        box.addView(row)

        val frame = FrameLayout(c)
        val m = dp(c, 10f).toInt()
        frame.addView(box, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply { setMargins(m, m, m, m) })
        val lp = overlayParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.TOP
            y = dp(c, 28f).toInt()
        }
        try {
            wm(c).addView(frame, lp)
            card = frame; status = st; leftBtn = l; rightBtn = r; orbSmall = orb
        } catch (t: Throwable) { Log.w(TAG, "card: ${t.javaClass.simpleName}") }
    }

    private fun pill(c: Context, primary: Boolean) = TextView(c).apply {
        setTextColor(Color.WHITE); textSize = 14f; typeface = Typeface.DEFAULT_BOLD
        val h = dp(c, 16f).toInt(); val v = dp(c, 8f).toInt()
        setPadding(h, v, h, v)
        background = if (primary) GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(OrbView.VIOLET, OrbView.PINK)).apply { cornerRadius = dp(c, 20f) }
        else GradientDrawable().apply { cornerRadius = dp(c, 20f); setColor(Color.parseColor("#33FFFFFF")) }
    }

    private fun button(b: TextView?, label: String, onTap: () -> Unit) {
        b ?: return
        b.visibility = View.VISIBLE; b.text = label
        b.setOnClickListener { onTap() }
    }

    private fun hideIn(ctx: Context, ms: Long) {
        autoHide?.let { main.removeCallbacks(it) }
        val r = Runnable { if (!busy) dismiss(ctx) }
        autoHide = r
        main.postDelayed(r, ms)
    }

    // ── listening and sending ────────────────────────────────────────────
    private val NO = Regex("^(no|nope|nah|skip|ignore|leave it|don'?t reply|not now|cancel|nahi|illa|beda)\\b", RegexOption.IGNORE_CASE)

    private fun listen(ctx: Context, action: Notification.Action) {
        val c = ctx.applicationContext
        autoHide?.let { main.removeCallbacks(it) }
        if (c.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            status?.text = "Allow the microphone in the app first"; hideIn(c, 8000); return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(c)) {
            status?.text = "Speech recognition is not available on this phone"; hideIn(c, 8000); return
        }
        busy = true
        MicService.acquire(c, "reply")
        orbSmall?.listening = true
        status?.text = "Listening — say your reply"
        rightBtn?.visibility = View.GONE
        button(leftBtn, "Dismiss") { dismiss(c) }
        val sr = SpeechRecognizer.createSpeechRecognizer(c)
        recognizer?.destroy(); recognizer = sr
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(p: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(v: Float) {}
            override fun onBufferReceived(b: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(t: Int, p: Bundle?) {}
            override fun onPartialResults(r: Bundle?) {
                val t = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                if (!t.isNullOrBlank()) status?.text = "“$t”"
            }
            override fun onResults(r: Bundle?) {
                stopListening(c)
                val text = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.trim().orEmpty()
                when {
                    text.isEmpty() -> missed(c, action)
                    NO.containsMatchIn(text) -> dismiss(c)
                    else -> countdown(c, action, text)
                }
            }
            override fun onError(code: Int) {
                stopListening(c)
                missed(c, action)
            }
        })
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            .putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500)
        try { sr.startListening(i) } catch (t: Throwable) { stopListening(c); missed(c, action) }
    }

    private fun stopListening(c: Context) {
        busy = false
        orbSmall?.listening = false
        try { recognizer?.destroy() } catch (_: Throwable) {}
        recognizer = null
        MicService.release(c, "reply")
    }

    private fun missed(c: Context, action: Notification.Action) {
        status?.text = "Didn't catch that"
        button(rightBtn, "Reply") { listen(c, action) }
        hideIn(c, 10_000)
    }

    private fun countdown(c: Context, action: Notification.Action, text: String) {
        busy = true
        var left = 3
        status?.text = "Sending “$text” in $left…"
        button(leftBtn, "Cancel") {
            pendingSend?.let { main.removeCallbacks(it) }; pendingSend = null
            busy = false
            status?.text = "Not sent"
            button(rightBtn, "Reply") { listen(c, action) }
            hideIn(c, 6000)
        }
        button(rightBtn, "Send now") { pendingSend?.let { main.removeCallbacks(it) }; send(c, action, text) }
        val tick = object : Runnable {
            override fun run() {
                left -= 1
                if (left <= 0) { send(c, action, text); return }
                status?.text = "Sending “$text” in $left…"
                pendingSend = this
                main.postDelayed(this, 1000)
            }
        }
        pendingSend = tick
        main.postDelayed(tick, 1000)
    }

    private fun send(c: Context, action: Notification.Action, text: String) {
        pendingSend = null
        busy = false
        val ok = HariNotificationListener.Sender.send(c, action, text)
        status?.text = if (ok) "Sent ✓" else "Couldn't send — open the app to reply"
        leftBtn?.visibility = View.GONE; rightBtn?.visibility = View.GONE
        hideIn(c, if (ok) 1500 else 5000)
    }

    fun dismiss(ctx: Context) {
        pendingSend?.let { main.removeCallbacks(it) }; pendingSend = null
        if (recognizer != null) stopListening(ctx.applicationContext)
        busy = false
        dismissNow()
    }

    private fun dismissNow() {
        autoHide?.let { main.removeCallbacks(it) }; autoHide = null
        val v = card ?: return
        card = null; status = null; leftBtn = null; rightBtn = null; orbSmall = null
        try { wm?.removeView(v) } catch (_: Throwable) {}
    }
}
