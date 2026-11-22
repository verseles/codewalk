package com.verseles.codewalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives `PackageInstaller.Session.commit()` status callbacks via an explicit
 * component `PendingIntent` and routes them to [ApkInstallBridge].
 */
class ApkInstallStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        ApkInstallBridge.onInstallStatus(context.applicationContext, intent)
    }
}
