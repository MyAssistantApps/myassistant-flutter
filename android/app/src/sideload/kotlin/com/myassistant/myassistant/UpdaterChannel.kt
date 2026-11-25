package com.myassistant.myassistant

import android.content.Context
import android.net.ConnectivityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * THE SELF-UPDATER'S NATIVE HALF — SIDELOADED BUILD ONLY (2026-11-25).
 *
 * Everything that installs a package lives in this source folder
 * (src/sideload/kotlin): this channel, ApkInstaller and QuietInstallJob.
 * android/app/build.gradle.kts compiles the folder into the sideloaded
 * build and leaves it out of a Google Play build (`-Pstore=play`), which
 * gets src/play/kotlin/…/UpdaterChannel.kt instead: the same name, and
 * nothing behind it. Google Play forbids an app that updates itself, so a
 * Play build must not merely switch the updater off — it must not contain
 * it. tool/check_play_build.sh proves that on every CI run.
 *
 * The Dart side is lib/services/app_update_service.dart ("hari/updater").
 */
object UpdaterChannel {
    /** True in the build that can update itself. */
    const val AVAILABLE = true

    fun register(messenger: BinaryMessenger, app: Context) {
        MethodChannel(messenger, "hari/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> ApkInstaller.install(
                        app,
                        call.argument<String>("path") ?: "",
                        call.argument<Boolean>("silent") ?: false
                    ) { ok -> result.success(ok) }
                    // Quiet updates: Android 12+ and not refused for this build.
                    "silentPossible" -> result.success(ApkInstaller.silentPossible(app))
                    // The app was left: install the verified build a few
                    // minutes from now (a system job — survives freezing).
                    "scheduleQuietInstall" -> result.success(
                        QuietInstallJob.schedule(
                            app,
                            call.argument<String>("path") ?: "",
                            (call.argument<Number>("delayMs") ?: 180000).toLong()
                        )
                    )
                    // The app is in use again: not now.
                    "cancelQuietInstall" -> {
                        QuietInstallJob.cancel(app)
                        result.success(true)
                    }
                    // Is the connection one the user pays for by the
                    // megabyte? A ~200 MB update must not start itself on
                    // mobile data. Unknown state is treated as metered:
                    // the cost of asking is a tap, the cost of guessing
                    // wrong is the user's data plan.
                    "isMetered" -> {
                        val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        result.success(cm?.isActiveNetworkMetered ?: true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
