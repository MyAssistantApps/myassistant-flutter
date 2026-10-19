package com.myassistant.myassistant

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * The app's orb, small (2026-10-19): a turning violet–pink–cyan ring with a
 * soft glow and the mic in the middle, in the same light as the in-app orb.
 * [listening] makes it breathe faster.
 */
class OrbView(context: Context, private val showMic: Boolean = true) : View(context) {
    companion object {
        val VIOLET = Color.parseColor("#8B5CFF")
        val PINK = Color.parseColor("#E040FB")
        val CYAN = Color.parseColor("#22E4FF")
        val NIGHT = Color.parseColor("#14102E")
    }

    var listening = false
        set(v) { field = v; invalidate() }

    private var turn = 0f
    private var pulse = 0f
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG)
    private val core = Paint(Paint.ANTI_ALIAS_FLAG)
    private val mic = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; style = Paint.Style.FILL }
    private val micLine = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND
    }
    private val m = Matrix()
    private val anim = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 4000
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            val f = it.animatedValue as Float
            turn = f * 360f
            val speed = if (listening) 4f else 2f
            pulse = ((Math.sin(f * Math.PI * 2 * speed) + 1) / 2).toFloat()
            invalidate()
        }
    }

    override fun onAttachedToWindow() { super.onAttachedToWindow(); anim.start() }
    override fun onDetachedFromWindow() { anim.cancel(); super.onDetachedFromWindow() }

    override fun onDraw(c: Canvas) {
        val w = width.toFloat(); val h = height.toFloat()
        val cx = w / 2; val cy = h / 2
        val r = minOf(w, h) / 2
        val inner = r * 0.74f

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
}
