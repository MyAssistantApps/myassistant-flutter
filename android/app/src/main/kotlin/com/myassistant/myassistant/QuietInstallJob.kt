package com.myassistant.myassistant

import android.app.ActivityManager
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
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
        if (inUse()) {
            android.util.Log.i(TAG, "app in use — quiet install skipped")
            return false
        }
        if (!File(path).exists()) return false
        android.util.Log.i(TAG, "installing quietly: $path")
        ApkInstaller.install(applicationContext, path, true) { _ ->
            jobFinished(params, false)
        }
        return true // the install runs on its own thread
    }

    override fun onStopJob(params: JobParameters): Boolean = false

    /** Is the app on screen (or visible) right now? */
    private fun inUse(): Boolean {
        val info = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(info)
        return info.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
    }

    companion object {
        private const val TAG = "HariUpdater"
        private const val JOB_ID = 4211
        private const val KEY_PATH = "path"

        /** Install [path] no sooner than [delayMs] from now (replaces any
         *  earlier request). */
        fun schedule(context: Context, path: String, delayMs: Long): Boolean {
            val js = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler
                ?: return false
            val extras = PersistableBundle().apply { putString(KEY_PATH, path) }
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, QuietInstallJob::class.java))
                .setMinimumLatency(delayMs)
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
