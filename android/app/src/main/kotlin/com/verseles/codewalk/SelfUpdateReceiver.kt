package com.verseles.codewalk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.io.File

/**
 * Persists a one-shot marker in private preferences (`cw2_apk_update`, separate
 * from `FlutterSharedPreferences`) immediately before committing a self-update
 * session, and posts a local notification on `ACTION_MY_PACKAGE_REPLACED` so
 * the user can reopen CodeWalk in one tap after Android terminates the old
 * process during package replacement.
 *
 * External installs (`adb install`, Play Store, third-party package managers)
 * have no marker and therefore never trigger a notification.
 */
object SelfUpdateNotifier {
    private const val PREFS_NAME = "cw2_apk_update"
    private const val KEY_AWAITING_REPLACE = "awaiting_replace"
    private const val KEY_EXPECTED_VERSION_CODE = "expected_version_code"
    private const val KEY_FROM_VERSION_CODE = "from_version_code"
    private const val KEY_TAG = "tag"
    private const val KEY_APK_PATH = "apk_path"
    private const val KEY_WRITTEN_AT_MS = "written_at_ms"
    private const val KEY_TITLE = "notif_title"
    private const val KEY_BODY = "notif_body"
    private const val KEY_CHANNEL = "notif_channel"
    private const val KEY_ASKED_NOTIF_PERMISSION = "asked_post_notifications"

    private const val CHANNEL_ID = "codewalk_updates"
    private const val NOTIFICATION_ID = 0xC0DE
    private const val MARKER_TTL_MS = 24L * 60L * 60L * 1000L
    private const val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"

    private const val DEFAULT_CHANNEL_NAME = "CodeWalk updates"
    private const val DEFAULT_TITLE = "CodeWalk updated"
    private const val DEFAULT_BODY = "Tap to reopen CodeWalk."

    fun updatesDirectory(context: Context): File =
        File(context.noBackupFilesDir, "updates")

    fun installedVersionCode(context: Context): Long {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Throwable) {
            0L
        }
    }

    fun wasNotificationPermissionAsked(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ASKED_NOTIF_PERMISSION, false)
    }

    fun markNotificationPermissionAsked(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_ASKED_NOTIF_PERMISSION, true).commit()
    }

    fun writeMarker(
        context: Context,
        expectedVersionCode: Long,
        tag: String?,
        apkPath: String,
        title: String?,
        body: String?,
        channelName: String?,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_AWAITING_REPLACE, true)
            .putLong(KEY_EXPECTED_VERSION_CODE, expectedVersionCode)
            .putLong(KEY_FROM_VERSION_CODE, installedVersionCode(context))
            .putString(KEY_TAG, tag ?: "")
            .putString(KEY_APK_PATH, apkPath)
            .putLong(KEY_WRITTEN_AT_MS, System.currentTimeMillis())
            .putString(KEY_TITLE, title ?: "")
            .putString(KEY_BODY, body ?: "")
            .putString(KEY_CHANNEL, channelName ?: "")
            .commit()
    }

    fun clearMarker(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val asked = prefs.getBoolean(KEY_ASKED_NOTIF_PERMISSION, false)
        prefs.edit()
            .clear()
            .putBoolean(KEY_ASKED_NOTIF_PERMISSION, asked)
            .commit()
    }

    fun onActivityResumed(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(NOTIFICATION_ID)
        } catch (_: Throwable) {
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_AWAITING_REPLACE, false)) return
        val writtenAt = prefs.getLong(KEY_WRITTEN_AT_MS, 0L)
        val expected = prefs.getLong(KEY_EXPECTED_VERSION_CODE, 0L)
        val fromCode = prefs.getLong(KEY_FROM_VERSION_CODE, 0L)
        val current = installedVersionCode(context)
        val now = System.currentTimeMillis()
        val expired = writtenAt <= 0L || now - writtenAt > MARKER_TTL_MS
        val landed = current > 0L &&
            ((expected > 0L && current >= expected) || (fromCode > 0L && current > fromCode))
        if (expired || landed) {
            clearMarker(context)
        }
    }

    fun onPackageReplaced(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_AWAITING_REPLACE, false)) return
        val writtenAt = prefs.getLong(KEY_WRITTEN_AT_MS, 0L)
        val expected = prefs.getLong(KEY_EXPECTED_VERSION_CODE, 0L)
        val fromCode = prefs.getLong(KEY_FROM_VERSION_CODE, 0L)
        val apkPath = prefs.getString(KEY_APK_PATH, null)
        val rawTitle = prefs.getString(KEY_TITLE, null)?.trim().orEmpty()
        val rawBody = prefs.getString(KEY_BODY, null)?.trim().orEmpty()
        val rawChannel = prefs.getString(KEY_CHANNEL, null)?.trim().orEmpty()
        clearMarker(context)
        deleteConsumedApk(context, apkPath)

        val now = System.currentTimeMillis()
        if (writtenAt <= 0L || now < writtenAt || now - writtenAt > MARKER_TTL_MS) return
        val current = installedVersionCode(context)
        if (current <= 0L) return
        if (expected > 0L && current < expected) return
        if (expected <= 0L && (fromCode <= 0L || current <= fromCode)) return

        postReplacedNotification(
            context = context,
            title = rawTitle.ifEmpty { DEFAULT_TITLE },
            body = rawBody.ifEmpty { DEFAULT_BODY },
            channelName = rawChannel.ifEmpty { DEFAULT_CHANNEL_NAME },
        )
    }

    private fun deleteConsumedApk(context: Context, apkPath: String?) {
        if (apkPath.isNullOrBlank()) return
        try {
            val root = updatesDirectory(context).canonicalFile
            val candidate = File(apkPath).canonicalFile
            if (candidate.exists() &&
                candidate.isFile &&
                candidate.path.startsWith(root.path + File.separator)
            ) {
                candidate.delete()
                val sidecar = File("${candidate.path}.json")
                if (sidecar.exists() && sidecar.isFile) {
                    sidecar.delete()
                }
            }
        } catch (_: Throwable) {
        }
    }

    private fun postReplacedNotification(
        context: Context,
        title: String,
        body: String,
        channelName: String,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(POST_NOTIFICATIONS_PERMISSION) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !nm.areNotificationsEnabled()) {
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    channelName,
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
                nm.createNotificationChannel(channel)
            }
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            val contentIntent = PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                launchIntent,
                pendingFlags,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            builder
                .setSmallIcon(R.drawable.ic_stat_codewalk)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setCategory(Notification.CATEGORY_STATUS)
            nm.notify(NOTIFICATION_ID, builder.build())
        } catch (_: Throwable) {
        }
    }
}

class SelfUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        SelfUpdateNotifier.onPackageReplaced(context.applicationContext)
    }
}
