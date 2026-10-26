package com.myassistant.myassistant

import android.app.Notification
import android.app.NotificationManager
import android.app.RemoteInput
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * EVERY NOTIFICATION, SORTED (2026-10-19, owner: "any WhatsApp message or
 * any important thing … even Swiggy … inform the user, keep it in memory,
 * or respond").
 *
 * Android binds this once the owner grants Notification access (You →
 * Assistant over other apps), and keeps it running with the app closed.
 * Each new notification goes to the server's triage (POST /notify/triage),
 * which answers reply / inform / none and saves a lasting fact to memory
 * itself. Reply and inform become a pop-up over whatever is on screen
 * (Overlay); a reply is sent through the notification's own reply action.
 *
 * Never sent to the server: this app's own notifications, ongoing ones
 * (music, calls, navigation, downloads), group summaries, repeats, and
 * anything that looks like an OTP or a password.
 */
class HariNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "HariNotify"
        private val io = Executors.newSingleThreadExecutor()
        private val main = Handler(Looper.getMainLooper())
        private val OTP = Regex(
            "\\b(otp|one[- ]?time (pass(word|code)?|pin)|verification code|passcode|password|pin is|cvv)\\b|\\b\\d{4,8}\\b.{0,30}\\b(code|otp)\\b",
            RegexOption.IGNORE_CASE,
        )
        private val SKIP_CATEGORIES = setOf(
            Notification.CATEGORY_TRANSPORT, Notification.CATEGORY_PROGRESS,
            Notification.CATEGORY_SERVICE, Notification.CATEGORY_CALL,
            Notification.CATEGORY_NAVIGATION, Notification.CATEGORY_STOPWATCH,
            Notification.CATEGORY_SYSTEM,
        )
        private val SKIP_PACKAGES = setOf("android", "com.android.systemui", "com.android.providers.downloads")

        /** What was already handled: "pkg|title|text" → when. */
        private val seen = object : LinkedHashMap<String, Long>(64, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?) = size > 300
        }
    }

    /**
     * Android connects this whenever Notification access is granted. Unless
     * the owner's switch is on, it lets go at once: nothing is read, not
     * even locally (owner, 2026-10-20: "only if the user said").
     */
    override fun onListenerConnected() {
        super.onListenerConnected()
        if (!NotifyPrefs.repliesOn(applicationContext)) {
            try { requestUnbind() } catch (_: Throwable) {}
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            handle(sbn ?: return)
        } catch (t: Throwable) {
            Log.w(TAG, "skipped a notification: ${t.javaClass.simpleName}")
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        val ctx = applicationContext
        // Switched off since it connected: let go, read nothing.
        if (!NotifyPrefs.repliesOn(ctx)) { try { requestUnbind() } catch (_: Throwable) {}; return }
        val pkg = sbn.packageName ?: return
        if (pkg == packageName || pkg in SKIP_PACKAGES) return
        val n = sbn.notification ?: return
        if (n.flags and (Notification.FLAG_ONGOING_EVENT or Notification.FLAG_FOREGROUND_SERVICE or Notification.FLAG_GROUP_SUMMARY) != 0) return
        if (n.category in SKIP_CATEGORIES) return

        val ex = n.extras ?: return
        val (sender, last) = lastMessage(ex)
        val title = (ex.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: ex.getCharSequence(Notification.EXTRA_TITLE))?.toString()?.trim().orEmpty()
        val text = (last ?: ex.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
        if (text.isEmpty() && title.isEmpty()) return
        // A code or a password never leaves the phone.
        if (OTP.containsMatchIn("$title $text")) return

        val key = "$pkg|$title|$text"
        synchronized(seen) {
            val at = seen[key]
            if (at != null && System.currentTimeMillis() - at < 30 * 60_000) return
            seen[key] = System.currentTimeMillis()
        }

        val group = ex.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)
        val reply = replyAction(n)
        val app = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
        } catch (_: Throwable) { pkg }
        val who = if (group && !sender.isNullOrBlank()) "$title · $sender" else title

        io.execute {
            val verdict = triage(ctx, app, who, text, reply != null, group) ?: return@execute
            val action = verdict.optString("action")
            if (action != "reply" && action != "inform") return@execute
            val say = verdict.optString("say").ifBlank { "$who: $text" }
            main.post {
                if (!popupAllowed(ctx)) return@post
                if (action == "reply" && reply != null) {
                    Overlay.showReply(ctx, app, say, reply)
                } else {
                    Overlay.showInfo(ctx, app, say, verdict.optBoolean("remembered"))
                }
            }
        }
    }

    /** The newest message of a chat notification: (sender, text). */
    private fun lastMessage(ex: Bundle): Pair<String?, CharSequence?> {
        @Suppress("DEPRECATION")
        val msgs = ex.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return null to null
        val b = msgs.lastOrNull() as? Bundle ?: return null to null
        val text = b.getCharSequence("text")
        val sender = if (Build.VERSION.SDK_INT >= 28) {
            @Suppress("DEPRECATION")
            (b.getParcelable<android.app.Person>("sender_person"))?.name?.toString()
                ?: b.getCharSequence("sender")?.toString()
        } else b.getCharSequence("sender")?.toString()
        return sender to text
    }

    /** The action that takes typed text: the chat's own Reply. */
    private fun replyAction(n: Notification): Notification.Action? {
        val all = n.actions ?: return null
        val withInput = all.filter { a -> a.remoteInputs?.any { it.allowFreeFormInput } == true }
        return withInput.firstOrNull { Build.VERSION.SDK_INT >= 28 && it.semanticAction == Notification.Action.SEMANTIC_ACTION_REPLY }
            ?: withInput.firstOrNull()
    }

    /** Not on a dark screen, in Do Not Disturb, during a call or our own conversation. */
    private fun popupAllowed(ctx: Context): Boolean {
        if (!Settings.canDrawOverlays(ctx)) return false
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return false
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL) return false
        val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (am.mode == AudioManager.MODE_IN_CALL || am.mode == AudioManager.MODE_IN_COMMUNICATION) return false
        return true
    }

    private fun triage(ctx: Context, app: String, title: String, text: String, canReply: Boolean, group: Boolean): JSONObject? {
        val token = NotifyPrefs.token(ctx)
        val base = NotifyPrefs.baseUrl(ctx).trimEnd('/')
        if (token.isEmpty() || base.isEmpty()) return null
        return try {
            val c = URL("$base/notify/triage").openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 8000
            c.readTimeout = 15000
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            c.setRequestProperty("Authorization", "Bearer $token")
            val body = JSONObject()
                .put("app", app).put("title", title.take(120)).put("text", text.take(600))
                .put("can_reply", canReply).put("group", group)
            c.outputStream.use { it.write(body.toString().toByteArray()) }
            if (c.responseCode !in 200..299) {
                Log.w(TAG, "triage ${c.responseCode}")
                // Unreachable server: a chat can still be answered.
                return if (canReply) JSONObject().put("action", "reply").put("say", "$title: $text".take(90)) else null
            }
            JSONObject(c.inputStream.bufferedReader().use { it.readText() })
        } catch (t: Throwable) {
            Log.w(TAG, "triage failed: ${t.javaClass.simpleName}")
            if (canReply) JSONObject().put("action", "reply").put("say", "$title: $text".take(90)) else null
        }
    }

    /** Fills the chat's reply box and presses send — the owner's words only. */
    object Sender {
        fun send(ctx: Context, action: Notification.Action, text: String): Boolean = try {
            val inputs = action.remoteInputs ?: emptyArray()
            val intent = android.content.Intent()
            val results = Bundle()
            for (ri in inputs) results.putCharSequence(ri.resultKey, text)
            RemoteInput.addResultsToIntent(inputs, intent, results)
            action.actionIntent.send(ctx, 0, intent)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "reply failed: ${t.javaClass.simpleName}")
            false
        }
    }
}
