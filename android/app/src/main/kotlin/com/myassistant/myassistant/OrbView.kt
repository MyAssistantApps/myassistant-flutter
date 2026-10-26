package com.myassistant.myassistant

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.os.SystemClock
import android.view.View

/**
 * The app's orb, small (2026-10-19): a turning violet–pink–cyan ring with a
 * soft glow and the mic in the middle, in the same light as the in-app orb.
 * [listening] makes it breathe faster.
 *
 * THE FLOATING MIC SAYS WHEN TO SPEAK (owner, 2026-10-26): with [halo] it
 * stays still — at rest, while she thinks, while she speaks — and only on
 * the owner's turn ([userTurn]) does a green border of light run round it
 * and green rings ripple out. Movement means "speak now"; nothing else
 * moves it. That turn runs on its own clock, not the system animator, so
 * it shows with animations turned down (battery saver). Without [halo]
 * (the reply pop-up's small orb) it turns and breathes as before.
 */
class OrbView(
    context: Context,
    private val showMic: Boolean = true,
    private val halo: Boolean = false,
) : View(context) {
    companion object {
        val VIOLET = Color.parseColor("#8B5CFF")
        val PINK = Color.parseColor("#E040FB")
        val CYAN = Color.parseColor("#22E4FF")
        val NIGHT = Color.parseColor("#14102E")
        val GREEN = Color.parseColor("#22E07A")
        val MINT = Color.parseColor("#B6FFD6")

        /** With [halo]: the orb's share of the view; the border runs in the rest. */
        const val BODY = 0.78f
        private const val RIPPLE = 1600L
    }

    var listening = false
        set(v) { field = v; invalidate() }

    /** The owner's turn to speak: rings ripple out from the orb ([halo] only). */
    var userTurn = false
        set(v) { if (v && !field) rippleFrom = SystemClock.uptimeMillis(); field = v; invalidate() }

    private var lastT = 0L
    private var turn = 0f
    private var orbit = 0f
    private var breath = 0.0
    private var pulse = 0f
    private var rippleFrom = 0L
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG)
    private val core = Paint(Paint.ANTI_ALIAS_FLAG)
    private val mic = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
    private val micLine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND
    }
    private val border = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val ripple = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private var tail: SweepGradient? = null
    private var tailAt = Float.NaN
    private val m = Matrix()

    override fun onAttachedToWindow() { super.onAttachedToWindow(); lastT = 0L; invalidate() }

    /** One frame on: the same speeds as before (a turn every 4 s, a breath every 2 s, 1 s live). */
    private fun advance() {
        val now = SystemClock.uptimeMillis()
        // Back from hidden: carry on from where it was, no jump.
        val dt = if (lastT == 0L) 0L else minOf(now - lastT, 100L)
        lastT = now
        turn = (turn + dt * 360f / 4000f) % 360f
        orbit = (orbit + dt * 360f / (if (listening) 1400f else 2800f)) % 360f
        breath = (breath + dt * Math.PI * 2 / (if (listening) 1000.0 else 2000.0)) % (Math.PI * 2)
        pulse = ((Math.sin(breath) + 1) / 2).toFloat()
    }

    override fun onDraw(c: Canvas) {
        // The floating mic moves only on the owner's turn; still otherwise.
        val moving = !halo || userTurn
        if (moving) advance() else lastT = 0L
        // The next frame, for as long as it is on screen (hidden, it rests).
        if (moving && isShown) postInvalidateOnAnimation()
        val w = width.toFloat(); val h = height.toFloat()
        val cx = w / 2; val cy = h / 2
        val edge = minOf(w, h) / 2
        val r = if (halo) edge * BODY else edge
        val inner = r * 0.74f

        if (halo && userTurn) drawHalo(c, cx, cy, r, edge)

        // Glow behind, breathing.
        val g = r * (0.92f + 0.08f * pulse)
        glow.shader = RadialGradient(cx, cy, g, intArrayOf(
            Color.argb((110 + 60 * pulse).toInt(), 139, 92, 255), Color.argb(0, 224, 64, 251)),
            floatArrayOf(0.55f, 1f), Shader.TileMode.CLAMP)
        c.drawCircle(cx, cy, g, glow)

        // Night core.
        core.shader = RadialGradient(cx - inner * 0.3f, cy - inner * 0.35f, inner * 1.3f,
            intArrayOf(Color.parseColor("#2A1F5C"), NIGHT), null, Shader.TileMode.CLAMP)
        c.drawCircle(cx, cy, inner, core)

        // The turning ring.
        ring.strokeWidth = r * 0.12f
        val sweep = SweepGradient(cx, cy, intArrayOf(VIOLET, PINK, CYAN, VIOLET), null)
        m.setRotate(turn, cx, cy); sweep.setLocalMatrix(m)
        ring.shader = sweep
        c.drawCircle(cx, cy, inner + ring.strokeWidth * 0.2f, ring)

        if (!showMic) return
        // The mic: capsule, cradle, stem.
        val mw = inner * 0.36f; val mh = inner * 0.62f
        val top = cy - mh * 0.62f
        c.drawRoundRect(RectF(cx - mw / 2, top, cx + mw / 2, top + mh), mw / 2, mw / 2, mic)
        micLine.strokeWidth = inner * 0.09f
        val cr = mw * 0.95f
        c.drawArc(RectF(cx - cr, top + mh * 0.25f, cx + cr, top + mh + cr * 0.55f), 20f, 140f, false, micLine)
        c.drawLine(cx, top + mh + cr * 0.55f, cx, top + mh + cr * 0.95f, micLine)
    }

    /** The owner's turn: the green border round the orb [r], out to [edge], and its ripples. */
    private fun drawHalo(c: Canvas, cx: Float, cy: Float, r: Float, edge: Float) {
        // Two green rings ripple out, one after the other.
        val now = SystemClock.uptimeMillis()
        for (k in 0 until 2) {
            val e = now - rippleFrom - k * RIPPLE / 2
            if (e < 0) continue
            val f = (e % RIPPLE) / RIPPLE.toFloat()
            ripple.strokeWidth = edge * 0.05f * (1f - f) + 1f
            ripple.color = Color.argb((170 * (1f - f)).toInt(), 34, 224, 122)
            c.drawCircle(cx, cy, r + (edge - r) * f, ripple)
        }
        // A green track, and two lights chasing round it.
        val br = r + (edge - r) * 0.42f
        track.strokeWidth = edge * 0.035f
        track.color = Color.argb(110, 34, 224, 122)
        c.drawCircle(cx, cy, br, track)
        val clear = Color.argb(0, 34, 224, 122)
        val t = tail?.takeIf { tailAt == cx } ?: SweepGradient(cx, cy,
            intArrayOf(clear, GREEN, MINT, Color.WHITE, clear, GREEN, MINT, Color.WHITE),
            floatArrayOf(0f, 0.30f, 0.45f, 0.5f, 0.5f, 0.80f, 0.95f, 1f)).also { tail = it; tailAt = cx }
        m.setRotate(orbit, cx, cy); t.setLocalMatrix(m)
        border.shader = t
        border.strokeWidth = edge * 0.07f
        c.drawCircle(cx, cy, br, border)
    }
}
