package com.myassistant.myassistant

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * THE HOME-SCREEN WIDGETS (2026-11-08, Manish: "create phone widgets; after
 * opening the app it should ask if we want to add them, and show the
 * different designs").
 *
 * Four designs, all shortcuts into the app — none runs a service or keeps
 * a microphone open (see TaskWidgetProvider for why):
 *   talk       the Ask bar: a tap opens the app talking (the floating mic's
 *              EXTRA_TALK path, so it starts exactly as the bubble does)
 *   day        My day: the date, today's meetings / reminders / bills and
 *              what is next, from what the app last saw (saveDay)
 *   shortcuts  Talk, Price compare, Flights, Reminders
 *   orb        the mic orb (TaskWidgetProvider); opens the voice orb
 *
 * The app asks to place one with requestPinAppWidget: Android shows its own
 * "Add to home screen" dialog, and the user decides.
 */
object HomeWidgets {
    const val EXTRA_ROUTE = "hari_widget_route"
    private const val PREFS = "hari_home_widgets"

    private fun provider(kind: String): Class<out AppWidgetProvider>? = when (kind) {
        "talk" -> TalkWidgetProvider::class.java
        "day" -> DayWidgetProvider::class.java
        "shortcuts" -> ShortcutsWidgetProvider::class.java
        "orb" -> TaskWidgetProvider::class.java
        else -> null
    }

    fun pinSupported(ctx: Context): Boolean =
        AppWidgetManager.getInstance(ctx).isRequestPinAppWidgetSupported

    /** Asks the launcher to place [kind]; false when it cannot be asked. */
    fun pin(ctx: Context, kind: String): Boolean {
        val cls = provider(kind) ?: return false
        val mgr = AppWidgetManager.getInstance(ctx)
        if (!mgr.isRequestPinAppWidgetSupported) return false
        return try {
            mgr.requestPinAppWidget(ComponentName(ctx, cls), null, null)
        } catch (_: Throwable) {
            false
        }
    }

    /** How many of each design are on the home screen now. */
    fun placed(ctx: Context): Map<String, Int> {
        val mgr = AppWidgetManager.getInstance(ctx)
        return listOf("talk", "day", "shortcuts", "orb").associateWith { k ->
            mgr.getAppWidgetIds(ComponentName(ctx, provider(k)!!)).size
        }
    }

    /** Today's numbers from the app; My day redraws from them. */
    fun saveDay(ctx: Context, meetings: Int, reminders: Int, bills: Int, next: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("meetings", meetings)
            .putInt("reminders", reminders)
            .putInt("bills", bills)
            .putString("next", next)
            .putString("for", today())
            .apply()
        redraw(ctx, DayWidgetProvider::class.java)
    }

    /** Every placed widget redrawn: after an update, taps go where they now should. */
    fun redrawAll(ctx: Context) {
        for (k in listOf("talk", "day", "shortcuts", "orb")) redraw(ctx, provider(k)!!)
    }

    fun redraw(ctx: Context, cls: Class<out AppWidgetProvider>) {
        val mgr = AppWidgetManager.getInstance(ctx)
        val ids = mgr.getAppWidgetIds(ComponentName(ctx, cls))
        if (ids.isEmpty()) return
        ctx.sendBroadcast(Intent(ctx, cls).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
    }

    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /**
     * Opens the app on [route] ("talk", "price", "flights", "reminders", or ""
     * for just the app). CLEAR_TOP so a tap lands even when the app is
     * already open behind it (see TaskWidgetProvider).
     */
    fun open(ctx: Context, route: String, code: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            action = "com.myassistant.myassistant.WIDGET_$code"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            when (route) {
                "talk" -> putExtra(Overlay.EXTRA_TALK, true)
                "task" -> putExtra(TaskWidgetProvider.EXTRA_QUICK_TASK, true)
                "" -> {}
                else -> putExtra(EXTRA_ROUTE, route)
            }
        }
        return PendingIntent.getActivity(
            ctx, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    internal fun dayViews(ctx: Context): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_day)
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val fresh = p.getString("for", "") == today()
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        v.setTextViewText(
            R.id.day_greeting,
            when {
                hour < 12 -> "Good morning"
                hour < 17 -> "Good afternoon"
                else -> "Good evening"
            }
        )
        v.setTextViewText(R.id.day_date, SimpleDateFormat("EEEE, d MMM", Locale.getDefault()).format(Date()))
        // Yesterday's numbers are not today's: a dash until the app has
        // looked again, and a line that says so.
        fun n(key: String) = if (fresh) p.getInt(key, 0).toString() else "–"
        v.setTextViewText(R.id.day_meetings, n("meetings"))
        v.setTextViewText(R.id.day_reminders, n("reminders"))
        v.setTextViewText(R.id.day_bills, n("bills"))
        val next = p.getString("next", "") ?: ""
        v.setTextViewText(
            R.id.day_next,
            when {
                !fresh -> ctx.getString(R.string.widget_day_stale)
                next.isNotEmpty() -> "Next · $next"
                else -> ctx.getString(R.string.widget_day_clear)
            }
        )
        v.setOnClickPendingIntent(R.id.widget_root, open(ctx, "", 9401))
        v.setOnClickPendingIntent(R.id.day_talk, open(ctx, "talk", 9402))
        return v
    }
}

/** The Ask bar. */
class TalkWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = RemoteViews(context.packageName, R.layout.widget_talk)
        v.setOnClickPendingIntent(R.id.widget_root, HomeWidgets.open(context, "talk", 9400))
        for (id in ids) manager.updateAppWidget(id, v)
    }
}

/** My day. */
class DayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, HomeWidgets.dayViews(context))
    }
}

/** Shortcuts. */
class ShortcutsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = RemoteViews(context.packageName, R.layout.widget_shortcuts)
        v.setOnClickPendingIntent(R.id.sc_talk, HomeWidgets.open(context, "talk", 9410))
        v.setOnClickPendingIntent(R.id.sc_price, HomeWidgets.open(context, "price", 9411))
        v.setOnClickPendingIntent(R.id.sc_flights, HomeWidgets.open(context, "flights", 9412))
        v.setOnClickPendingIntent(R.id.sc_task, HomeWidgets.open(context, "reminders", 9413))
        for (id in ids) manager.updateAppWidget(id, v)
    }
}
