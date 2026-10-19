package com.myassistant.myassistant

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * What the native side needs while the app itself may not be running
 * (2026-10-19): the session token and server for the notification triage,
 * and the owner's two switches. The token is a copy the app hands over at
 * sign-in (and clears at sign-out); it is kept encrypted like the app's own.
 */
object NotifyPrefs {
    private const val FILE = "hari_overlay_prefs"
    @Volatile private var prefs: SharedPreferences? = null

    private fun p(ctx: Context): SharedPreferences {
        prefs?.let { return it }
        synchronized(this) {
            prefs?.let { return it }
            val app = ctx.applicationContext
            val made = try {
                val key = MasterKey.Builder(app).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
                EncryptedSharedPreferences.create(
                    app, FILE, key,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (_: Throwable) {
                // A broken keystore must not take the feature down with it.
                app.getSharedPreferences("${FILE}_plain", Context.MODE_PRIVATE)
            }
            prefs = made
            return made
        }
    }

    fun token(ctx: Context): String = p(ctx).getString("token", "") ?: ""
    fun baseUrl(ctx: Context): String = p(ctx).getString("base_url", "") ?: ""
    fun setAuth(ctx: Context, token: String?, baseUrl: String?) {
        p(ctx).edit().putString("token", token ?: "").putString("base_url", baseUrl ?: "").apply()
    }

    /** Pop-ups for notifications (reply / inform). */
    fun repliesOn(ctx: Context): Boolean = p(ctx).getBoolean("replies_on", false)
    fun setRepliesOn(ctx: Context, on: Boolean) = p(ctx).edit().putBoolean("replies_on", on).apply()

    /** The floating mic over other apps. */
    fun bubbleOn(ctx: Context): Boolean = p(ctx).getBoolean("bubble_on", false)
    fun setBubbleOn(ctx: Context, on: Boolean) = p(ctx).edit().putBoolean("bubble_on", on).apply()
}
