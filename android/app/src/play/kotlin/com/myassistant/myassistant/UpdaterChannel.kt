package com.myassistant.myassistant

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/**
 * GOOGLE PLAY BUILD: THERE IS NO SELF-UPDATER (2026-11-25).
 *
 * Google Play forbids an app that updates itself; the Play Store updates
 * this build. android/app/build.gradle.kts compiles this file instead of
 * src/sideload/kotlin (the real channel, ApkInstaller and QuietInstallJob)
 * when the build is made with `-Pstore=play`, so a Play build contains no
 * code that downloads or installs a package. The Dart side is off in the
 * same build (AppUpdateService.enabled = !kPlayStoreBuild) and never calls
 * the channel, so none is registered.
 *
 * Keep this file free of anything that installs, schedules or downloads:
 * tool/check_play_build.sh fails the build if such code reaches a Play
 * build.
 */
object UpdaterChannel {
    /** False: this build cannot update itself. */
    const val AVAILABLE = false

    @Suppress("UNUSED_PARAMETER")
    fun register(messenger: BinaryMessenger, app: Context) {
        // Nothing to register.
    }
}
