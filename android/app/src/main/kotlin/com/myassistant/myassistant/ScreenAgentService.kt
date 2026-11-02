package com.myassistant.myassistant

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Color
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * TASKS INSIDE OTHER APPS (owner, 2026-11-01: "should be able to open any
 * app I asked for and do task", with confirmations).
 *
 * The phone's hands for a screen task (lib/services/screen_agent.dart runs
 * the loop, the server picks each step: backend ai/screenTask.js). This
 * service only does what it is told, one step at a time, and only while a
 * task is running:
 *   dump()    what is on screen, as numbered elements (password fields are
 *             marked and their text is never read)
 *   act()     tap / type / scroll / back on one of those elements
 *   status()  a pill over the other app: what she is doing, and STOP
 *   confirm() an Allow / Stop card before anything that sends, pays,
 *             orders or deletes — the task waits for the owner's tap
 * The owner switches it on in Settings → Accessibility; it reacts to no
 * event on its own.
 */
class ScreenAgentService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: ScreenAgentService? = null
        private const val MAX_NODES = 220

        /** Places a task never acts in (the installer, this app). */
        private val OFF_LIMITS = setOf(
            "com.android.packageinstaller", "com.google.android.packageinstaller",
        )
    }

    private val main = Handler(Looper.getMainLooper())
    private val nodes = ArrayList<AccessibilityNodeInfo>()
    @Volatile var stopRequested = false
        private set
    private var statusView: View? = null
    private var statusText: TextView? = null
    private var confirmView: View? = null
    private var pendingConfirm: ((Boolean) -> Unit)? = null

    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        hide()
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        hide()
        instance = null
        super.onDestroy()
    }

    // ------------------------------------------------------------- reading

    fun dump(): Map<String, Any?> {
        nodes.clear()
        val root = rootInActiveWindow ?: return mapOf("pkg" to "", "nodes" to emptyList<Any>())
        val out = ArrayList<Map<String, Any?>>()
        walk(root, out, 0)
        return mapOf("pkg" to (root.packageName?.toString() ?: ""), "nodes" to out)
    }

    private fun walk(n: AccessibilityNodeInfo, out: MutableList<Map<String, Any?>>, depth: Int) {
        if (out.size >= MAX_NODES || depth > 45) return
        if (!n.isVisibleToUser) return
        val text = n.text?.toString()?.trim().orEmpty()
        val desc = n.contentDescription?.toString()?.trim().orEmpty()
        val hint = if (Build.VERSION.SDK_INT >= 26) n.hintText?.toString()?.trim().orEmpty() else ""
        val tappable = n.isClickable || n.isLongClickable
        val useful = tappable || n.isEditable || n.isScrollable || text.isNotEmpty() || desc.isNotEmpty()
        if (useful) {
            val i = nodes.size
            nodes.add(n)
            val b = Rect().also { n.getBoundsInScreen(it) }
            out.add(mapOf(
                "i" to i,
                // A password's text is never read.
                "text" to if (n.isPassword) "" else text.take(120),
                "desc" to desc.take(120),
                "hint" to hint.take(60),
                "id" to (n.viewIdResourceName ?: ""),
                "cls" to (n.className?.toString() ?: ""),
                "click" to (tappable || clickableAncestor(n) != null),
                "edit" to n.isEditable,
                "scroll" to n.isScrollable,
                "pw" to n.isPassword,
                "focus" to n.isFocused,
                "b" to listOf(b.left, b.top, b.right, b.bottom),
            ))
        }
        for (c in 0 until n.childCount) {
            val child = n.getChild(c) ?: continue
            walk(child, out, depth + 1)
        }
    }

    private fun clickableAncestor(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var p: AccessibilityNodeInfo? = n.parent
        var hops = 0
        while (p != null && hops < 6) {
            if (p.isClickable) return p
            p = p.parent
            hops++
        }
        return null
    }

    // -------------------------------------------------------------- acting

    /** One step. Returns null on success, or why it could not be done. */
    fun act(action: String, index: Int?, text: String?, direction: String?): String? {
        val pkg = rootInActiveWindow?.packageName?.toString().orEmpty()
        if (pkg in OFF_LIMITS || pkg == packageName) return "that screen is off limits"
        if (action == "back") return if (performGlobalAction(GLOBAL_ACTION_BACK)) null else "back did nothing"
        val node = index?.let { nodes.getOrNull(it) }
        when (action) {
            "tap" -> {
                node ?: return "no such element"
                val target = if (node.isClickable) node else clickableAncestor(node)
                if (target != null && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return null
                return if (tapAt(node)) null else "the tap did not land"
            }
            "type" -> {
                node ?: return "no such element"
                if (node.isPassword) return "passwords are typed by the owner"
                node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                val args = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text ?: "")
                }
                return if (node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) null
                else "that field would not take text"
            }
            "scroll" -> {
                val target = node?.takeIf { it.isScrollable } ?: nodes.firstOrNull { it.isScrollable }
                val forward = direction != "up"
                val act = if (forward) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                if (target != null && target.performAction(act)) return null
                return if (swipe(forward)) null else "nothing to scroll"
            }
        }
        return "unknown step $action"
    }

    private fun tapAt(n: AccessibilityNodeInfo): Boolean {
        val b = Rect().also { n.getBoundsInScreen(it) }
        if (b.isEmpty) return false
        val p = Path().apply { moveTo(b.exactCenterX(), b.exactCenterY()) }
        return dispatchGesture(GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p, 0, 60)).build(), null, null)
    }

    private fun swipe(forward: Boolean): Boolean {
        val dm = resources.displayMetrics
        val x = dm.widthPixels / 2f
        val (from, to) = if (forward) dm.heightPixels * 0.72f to dm.heightPixels * 0.30f
        else dm.heightPixels * 0.30f to dm.heightPixels * 0.72f
        val p = Path().apply { moveTo(x, from); lineTo(x, to) }
        return dispatchGesture(GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p, 0, 320)).build(), null, null)
    }

    // ------------------------------------------------------------ overlays

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics).toInt()

    private fun params(gravity: Int) = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        PixelFormat.TRANSLUCENT,
    ).apply { this.gravity = gravity }

    private fun card(): LinearLayout = LinearLayout(this).apply {
        setPadding(dp(16f), dp(12f), dp(12f), dp(12f))
        background = GradientDrawable().apply {
            cornerRadius = dp(18f).toFloat()
            setColor(Color.parseColor("#F2121530"))
            setStroke(dp(1f), Color.parseColor("#88FFC857"))
        }
    }

    private fun button(label: String, primary: Boolean, onTap: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextColor(if (primary) Color.parseColor("#1A1200") else Color.WHITE)
        background = GradientDrawable().apply {
            cornerRadius = dp(14f).toFloat()
            setColor(Color.parseColor(if (primary) "#FFC857" else "#33FFFFFF"))
        }
        setOnClickListener { onTap() }
    }

    /** The pill over the other app while a task runs: what she does, and Stop. */
    fun status(say: String) = main.post {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        if (statusView == null) {
            val text = TextView(this).apply {
                setTextColor(Color.WHITE)
                textSize = 14f
                maxLines = 2
            }
            val row = card().apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(text, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                addView(button("Stop", false) {
                    stopRequested = true
                    statusText?.text = "Stopping…"
                })
            }
            val wrap = LinearLayout(this).apply {
                setPadding(dp(12f), dp(36f), dp(12f), 0)
                addView(row)
            }
            try { wm.addView(wrap, params(Gravity.TOP)) } catch (_: Exception) { return@post }
            statusView = wrap
            statusText = text
            stopRequested = false
        }
        statusText?.text = "✦ $say"
    }

    /** Ask before a consequential tap; [done] gets true only for Allow. */
    fun confirm(question: String, done: (Boolean) -> Unit) = main.post {
        dismissConfirm(false)
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val body = card().apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(this@ScreenAgentService).apply {
                text = "Your assistant wants to:"
                setTextColor(Color.parseColor("#FFC857"))
                textSize = 13f
            })
            addView(TextView(this@ScreenAgentService).apply {
                text = question
                setTextColor(Color.WHITE)
                textSize = 17f
                setPadding(0, dp(4f), 0, dp(10f))
            })
            addView(LinearLayout(this@ScreenAgentService).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                addView(button("Stop", false) { dismissConfirm(false) })
                addView(View(this@ScreenAgentService), LinearLayout.LayoutParams(dp(10f), 1))
                addView(button("Allow", true) { dismissConfirm(true) })
            })
        }
        val wrap = LinearLayout(this).apply {
            setPadding(dp(12f), 0, dp(12f), dp(28f))
            addView(body)
        }
        try {
            wm.addView(wrap, params(Gravity.BOTTOM))
        } catch (_: Exception) {
            done(false)
            return@post
        }
        confirmView = wrap
        pendingConfirm = done
        // No answer in a minute is a no.
        main.postDelayed({ if (pendingConfirm === done) dismissConfirm(false) }, 60_000)
    }

    private fun dismissConfirm(allowed: Boolean) {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        confirmView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        confirmView = null
        val cb = pendingConfirm
        pendingConfirm = null
        cb?.invoke(allowed)
    }

    /** The task is over: every overlay goes. */
    fun hide() = main.post {
        dismissConfirm(false)
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        statusView?.let { try { wm.removeView(it) } catch (_: Exception) {} }
        statusView = null
        statusText = null
    }
}

/** Opens Settings → Accessibility, where the owner switches the service on. */
fun openAccessibilitySettings(ctx: android.content.Context) {
    ctx.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}
