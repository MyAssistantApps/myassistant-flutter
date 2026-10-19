package com.myassistant.myassistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * The two small foreground services behind the overlay (2026-10-19).
 *
 * BubbleService keeps the floating mic alive while it is switched on
 * (started from the app, in front, when the owner turns it on).
 *
 * MicService runs only while a reply pop-up is listening: Android lets an
 * app use the microphone in the background only from a foreground service
 * of the microphone type, and lets it start one while its overlay is on
 * screen. It stops the moment listening ends.
 */
private fun ensureChannel(ctx: Context) {
    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (nm.getNotificationChannel("hari_overlay") == null) {
        nm.createNotificationChannel(NotificationChannel(
            "hari_overlay", "Assistant over other apps", NotificationManager.IMPORTANCE_MIN))
    }
}

private fun note(ctx: Context, text: String, stop: Boolean = false): Notification {
    ensureChannel(ctx)
    val open = android.app.PendingIntent.getActivity(ctx, 0,
        Intent(ctx, MainActivity::class.java), android.app.PendingIntent.FLAG_IMMUTABLE)
    val b = Notification.Builder(ctx, "hari_overlay")
        .setSmallIcon(ctx.applicationInfo.icon)
        .setContentTitle(text)
        .setContentIntent(open)
        .setOngoing(true)
    if (stop) {
        // STOP (owner, 2026-10-19): everything over other apps off, the app closed.
        val halt = android.app.PendingIntent.getService(ctx, 1,
            Intent(ctx, BubbleService::class.java).setAction(BubbleService.ACTION_STOP),
            android.app.PendingIntent.FLAG_IMMUTABLE)
        b.addAction(Notification.Action.Builder(null, "Stop", halt).build())
    }
    return b.build()
}

class BubbleService : Service() {
    companion object {
        const val ACTION_STOP = "com.myassistant.myassistant.STOP_OVERLAY"
        fun start(ctx: Context) = try {
            ctx.startForegroundService(Intent(ctx, BubbleService::class.java)); true
        } catch (t: Throwable) { Log.w("HariOverlay", "bubble service: ${t.javaClass.simpleName}"); false }
        fun stop(ctx: Context) { ctx.stopService(Intent(ctx, BubbleService::class.java)) }
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopEverything(); return START_NOT_STICKY }
        val n = note(this, "Assistant is ready over other apps", stop = true)
        if (Build.VERSION.SDK_INT >= 34) startForeground(41, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(41, n)
        Overlay.showBubble(this)
        return START_STICKY
    }
    override fun onDestroy() { Overlay.hideBubble(); super.onDestroy() }

    /**
     * The notification's Stop: the floating mic and the pop-ups switched
     * off (turned back on in You → Over other apps), any conversation
     * ended, the microphone released, and the app closed.
     */
    private fun stopEverything() {
        val ctx = applicationContext
        NotifyPrefs.setBubbleOn(ctx, false)
        NotifyPrefs.setRepliesOn(ctx, false)
        Overlay.hideBubble()
        Overlay.dismiss(ctx)
        try { Overlay.dart?.invokeMethod("stopAll", null) } catch (_: Throwable) {}
        MicService.releaseAll(ctx)
        try { startForeground(41, note(this, "Stopping")) } catch (_: Throwable) {}
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        // Give the conversation a moment to close, then end the app's process.
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            android.os.Process.killProcess(android.os.Process.myPid())
        }, 700)
    }
}

class MicService : Service() {
    companion object {
        // Who needs the microphone: the reply pop-up and a bubble
        // conversation can overlap; it stops when the last one lets go.
        private val holders = mutableSetOf<String>()

        fun acquire(ctx: Context, who: String): Boolean = synchronized(holders) {
            holders.add(who)
            try {
                ctx.startForegroundService(Intent(ctx, MicService::class.java)); true
            } catch (t: Throwable) { Log.w("HariOverlay", "mic service: ${t.javaClass.simpleName}"); false }
        }

        fun releaseAll(ctx: Context) = synchronized(holders) {
            holders.clear()
            ctx.stopService(Intent(ctx, MicService::class.java))
        }

        fun release(ctx: Context, who: String) = synchronized(holders) {
            holders.remove(who)
            if (holders.isEmpty()) ctx.stopService(Intent(ctx, MicService::class.java))
        }
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = note(this, "Assistant is listening")
        try {
            if (Build.VERSION.SDK_INT >= 30) startForeground(42, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            else startForeground(42, n)
        } catch (t: Throwable) {
            Log.w("HariOverlay", "mic foreground refused: ${t.javaClass.simpleName}")
            stopSelf()
        }
        return START_NOT_STICKY
    }
}
