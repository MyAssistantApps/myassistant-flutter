package com.myassistant.myassistant

import android.app.ActivityManager
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.media.AudioManager
import android.os.PersistableBundle
import java.io.File

/**
 * QUIET UPDATES (owner, 2026-11-23: "update silently without the user
 * knowing"). The app has downloaded and verified the new build; once it is
 * left, this job installs it a few minutes later.
 *
 * Why a JobScheduler job and not a timer in the app: Android 12+ freezes an
 * app's process soon after it leaves the screen, so a timer in it never
 * fires in the background — it fired the moment the user came back, and the
 * update then closed the app they had just opened. The system runs a job
 * even for a frozen or stopped app. The app cancels the job when it is
 * opened again, and the job checks once more that nobody is using it.
 */
class QuietInstallJob : JobService() {

    override fun onStartJob(params: JobParameters): Boolean {
        val path = params.extras.getString(KEY_PATH) ?: return false
        if (!File(path).exists()) return false
        // Only ever forward: a file left from an update that already went
        // in (or an older one) is never installed over the running build.
        if (archiveBuild(path) <= ApkInstaller.currentBuild(applicationContext)) return false
        if (inUse() || inCall()) {
            // Not now: the system runs it again a few minutes later (the
            // backoff below). Opening the app cancels it; leaving the app
            // schedules it afresh.
            android.util.Log.i(TAG, "app in use or a call is on — quiet install moved on")
            android.os.Handler(mainLooper).post { jobFinished(params, true) }
            return true
        }
        android.util.Log.i(TAG, "installing quietly: $path")
        ApkInstaller.install(applicationContext, path, true) { _ ->
            jobFinished(params, false)
        }
        return true // the install runs on its own thread
    }

    override fun onStopJob(params: JobParameters): Boolean = false

    /** The build number inside the APK at [path] (-1 when unreadable). */
    @Suppress("DEPRECATION")
    private fun archiveBuild(path: String): Long = try {
        val pi = packageManager.getPackageArchiveInfo(path, 0)
        when {
            pi == null -> -1L
            android.os.Build.VERSION.SDK_INT >= 28 -> pi.longVersionCode
            else -> pi.versionCode.toLong()
        }
    } catch (_: Exception) {
        -1L
    }

    /** Is the app on screen right now? Its own activity says so (Overlay.
     *  appVisible, set on resume / pause); a process that is merely kept up
     *  by a foreground service or the notification listener is NOT in use —
     *  counting that (importance 125) blocked every quiet install on phones
     *  with those switched on. Visible-but-paused (split screen) still is. */
    private fun inUse(): Boolean {
        if (Overlay.appVisible) return true
        val info = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(info)
        return info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }

    /** A phone or internet call (or the assistant's own voice session) is on:
     *  replacing the app now would cut what follows the call. */
    private fun inCall(): Boolean {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        return am.mode == AudioManager.MODE_IN_CALL ||
            am.mode == AudioManager.MODE_IN_COMMUNICATION ||
            am.mode == AudioManager.MODE_RINGTONE
    }

    companion object {
        private const val TAG = "HariUpdater"
        private const val JOB_ID = 4211
        private const val KEY_PATH = "path"
        private const val RETRY_MS = 3 * 60 * 1000L

        /** Install [path] no sooner than [delayMs] from now (replaces any
         *  earlier request). */
        fun schedule(context: Context, path: String, delayMs: Long): Boolean {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
                ?: return false
            val extras = PersistableBundle().apply { putString(KEY_PATH, path) }
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, QuietInstallJob::class.java))
                .setMinimumLatency(delayMs)
                .setBackoffCriteria(RETRY_MS, JobInfo.BACKOFF_POLICY_LINEAR)
                .setExtras(extras)
                .build()
            return js.schedule(job) == JobScheduler.RESULT_SUCCESS
        }

        fun cancel(context: Context) {
            (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler)
                ?.cancel(JOB_ID)
        }
    }
}
