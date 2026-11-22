package com.verseles.codewalk

import android.app.Activity
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Native Android `PackageInstaller` session bridge for CodeWalk self-updates.
 *
 * Integrity (manifest, SHA-256, signer SHA-256, strictly increasing
 * `versionCode`) is verified in Dart before calling [onMethodCall]. This bridge:
 * 1. Verifies the file path resides inside `noBackupFilesDir/updates`.
 * 2. On Android 8+ (API 26+), checks `canRequestPackageInstalls()`; if false,
 *    opens `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for this package and
 *    continues directly into the session when granted on return (or returns
 *    `"denied"` if still ungranted).
 * 3. On Android 13+ (API 33+), requests `POST_NOTIFICATIONS` once before
 *    committing so silent self-update replacement does not kill the permission
 *    prompt mid-flight, proceeding unconditionally whether granted or denied.
 * 4. Streams the verified APK into a `PackageInstaller.Session` with
 *    `USER_ACTION_NOT_REQUIRED` on Android 12+ (API 31+), writes the private
 *    `cw2_apk_update` marker, and commits with an explicit mutable
 *    `PendingIntent` targeting [ApkInstallStatusReceiver].
 */
object ApkInstallBridge : MethodChannel.MethodCallHandler {
    const val CHANNEL_NAME = "com.verseles.codewalk/v2-apk-install"
    const val REQ_UNKNOWN_SOURCES = 0x4357
    const val REQ_POST_NOTIFICATIONS = 0x4358

    private const val EXTRA_TOKEN = "com.verseles.codewalk.extra.INSTALL_TOKEN"
    private const val EXTRA_SESSION_ID = "com.verseles.codewalk.extra.SESSION_ID"
    private const val POST_NOTIFICATIONS_PERMISSION = "android.permission.POST_NOTIFICATIONS"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var appContext: Context? = null
    private var activity: Activity? = null
    private var channel: MethodChannel? = null

    private data class PendingRequest(
        val apkFile: File,
        val expectedVersionCode: Long,
        val tag: String?,
        val notificationTitle: String?,
        val notificationBody: String?,
        val notificationChannel: String?,
        val result: MethodChannel.Result,
    )

    private var pendingRequest: PendingRequest? = null
    private var awaitingUnknownSources = false
    private var awaitingNotificationPermission = false
    private var committerRunning = false

    @Volatile
    private var activeSessionId: Int? = null

    @Volatile
    private var activeToken: String? = null

    @Volatile
    private var activeSessionPath: String? = null

    @Volatile
    private var awaitingUserConfirmation = false

    @Volatile
    private var lastConfirmationIntent: Intent? = null

    private val unknownSourcesResumeFallback = Runnable {
        if (awaitingUnknownSources) {
            onActivityResult(REQ_UNKNOWN_SOURCES)
        }
    }

    private val notificationPermissionResumeFallback = Runnable {
        val request = pendingRequest ?: return@Runnable
        if (!awaitingNotificationPermission) return@Runnable
        awaitingNotificationPermission = false
        startSessionCommit(request)
    }

    fun attach(activity: Activity, channel: MethodChannel) {
        this.appContext = activity.applicationContext
        this.activity = activity
        this.channel = channel
        channel.setMethodCallHandler(this)
    }

    fun detach(leavingActivity: Activity) {
        if (this.activity !== leavingActivity) return
        mainHandler.removeCallbacks(unknownSourcesResumeFallback)
        mainHandler.removeCallbacks(notificationPermissionResumeFallback)
        val pending = pendingRequest
        pendingRequest = null
        awaitingUnknownSources = false
        awaitingNotificationPermission = false
        this.activity = null
        this.channel?.setMethodCallHandler(null)
        this.channel = null
        if (pending != null && !committerRunning) {
            try {
                pending.result.success("failed")
            } catch (_: Throwable) {
            }
        }
    }

    fun onActivityResume(resumedActivity: Activity) {
        this.activity = resumedActivity
        this.appContext = resumedActivity.applicationContext
        SelfUpdateNotifier.onActivityResumed(resumedActivity.applicationContext)
        if (awaitingUnknownSources) {
            mainHandler.removeCallbacks(unknownSourcesResumeFallback)
            mainHandler.post(unknownSourcesResumeFallback)
        }
        if (awaitingNotificationPermission) {
            mainHandler.removeCallbacks(notificationPermissionResumeFallback)
            mainHandler.post(notificationPermissionResumeFallback)
        }
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQ_UNKNOWN_SOURCES) return false
        mainHandler.removeCallbacks(unknownSourcesResumeFallback)
        val request = pendingRequest ?: return true
        if (!awaitingUnknownSources) return true
        awaitingUnknownSources = false
        val context = activity ?: appContext
        val canInstall = if (context == null) {
            false
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
        if (!canInstall) {
            pendingRequest = null
            request.result.success("denied")
            return true
        }
        maybeRequestNotificationsThenCommit(request)
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQ_POST_NOTIFICATIONS) return false
        mainHandler.removeCallbacks(notificationPermissionResumeFallback)
        val context = activity ?: appContext
        if (context != null) {
            SelfUpdateNotifier.markNotificationPermissionAsked(context)
        }
        val request = pendingRequest ?: return true
        if (!awaitingNotificationPermission) return true
        awaitingNotificationPermission = false
        startSessionCommit(request)
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity ?: appContext
        if (context == null) {
            result.success("noInstaller")
            return
        }
        when (call.method) {
            "updatesDirectory" -> {
                try {
                    val dir = SelfUpdateNotifier.updatesDirectory(context)
                    if (!dir.exists()) {
                        dir.mkdirs()
                    }
                    result.success(dir.canonicalPath)
                } catch (error: Throwable) {
                    result.error("STORAGE", error.message, null)
                }
            }
            "clearPendingMarker" -> {
                SelfUpdateNotifier.clearMarker(context)
                result.success(null)
            }
            "open" -> handleOpen(context, call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleOpen(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingRequest != null || committerRunning) {
            result.success("failed")
            return
        }
        val rawPath = call.argument<String>("path")?.trim().orEmpty()
        if (rawPath.isEmpty()) {
            result.success("fileMissing")
            return
        }
        val apkFile = try {
            val root = SelfUpdateNotifier.updatesDirectory(context).canonicalFile
            val candidate = File(rawPath).canonicalFile
            if (!candidate.exists() ||
                !candidate.isFile ||
                candidate.length() <= 0L ||
                !candidate.path.startsWith(root.path + File.separator)
            ) {
                null
            } else {
                candidate
            }
        } catch (_: Throwable) {
            null
        }
        if (apkFile == null) {
            result.success("fileMissing")
            return
        }

        // If an existing committed session for the exact same APK file is still
        // alive in PackageInstaller, either relaunch its stored confirmation
        // Intent (when awaiting user confirmation) or report it as already
        // committed without abandoning the in-flight session.
        val existingSessionId = activeSessionId
        val existingPath = activeSessionPath
        val existingConfirm = lastConfirmationIntent
        if (existingSessionId != null && existingPath == apkFile.path) {
            val stillPresent = try {
                context.packageManager.packageInstaller.getSessionInfo(existingSessionId) != null
            } catch (_: Throwable) {
                false
            }
            if (stillPresent) {
                if (awaitingUserConfirmation && existingConfirm != null) {
                    if (launchConfirmationIntent(context, Intent(existingConfirm))) {
                        result.success("opened")
                        return
                    }
                } else if (!awaitingUserConfirmation) {
                    result.success("committed")
                    return
                }
            }
        }

        val versionCodeArg = (call.argument<Number>("versionCode"))?.toLong() ?: 0L
        val tag = call.argument<String>("tag")
        val title = call.argument<String>("notificationTitle")
        val body = call.argument<String>("notificationBody")
        val channelName = call.argument<String>("notificationChannel")

        val request = PendingRequest(
            apkFile = apkFile,
            expectedVersionCode = versionCodeArg,
            tag = tag,
            notificationTitle = title,
            notificationBody = body,
            notificationChannel = channelName,
            result = result,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            val hostActivity = activity
            if (hostActivity == null) {
                result.success("denied")
                return
            }
            pendingRequest = request
            awaitingUnknownSources = true
            val launched = launchUnknownSourcesSettings(hostActivity)
            if (!launched) {
                pendingRequest = null
                awaitingUnknownSources = false
                result.success("denied")
            }
            return
        }

        pendingRequest = request
        maybeRequestNotificationsThenCommit(request)
    }

    private fun launchUnknownSourcesSettings(hostActivity: Activity): Boolean {
        val scoped = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${hostActivity.packageName}"),
        )
        return try {
            hostActivity.startActivityForResult(scoped, REQ_UNKNOWN_SOURCES)
            true
        } catch (_: ActivityNotFoundException) {
            try {
                val fallback = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                hostActivity.startActivityForResult(fallback, REQ_UNKNOWN_SOURCES)
                true
            } catch (_: Throwable) {
                false
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun maybeRequestNotificationsThenCommit(request: PendingRequest) {
        val hostActivity = activity
        val context = hostActivity ?: appContext
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            hostActivity != null &&
            context != null &&
            context.checkSelfPermission(POST_NOTIFICATIONS_PERMISSION) !=
            PackageManager.PERMISSION_GRANTED &&
            !SelfUpdateNotifier.wasNotificationPermissionAsked(context)
        ) {
            awaitingNotificationPermission = true
            try {
                hostActivity.requestPermissions(
                    arrayOf(POST_NOTIFICATIONS_PERMISSION),
                    REQ_POST_NOTIFICATIONS,
                )
                return
            } catch (_: Throwable) {
                awaitingNotificationPermission = false
            }
        }
        startSessionCommit(request)
    }

    private fun startSessionCommit(request: PendingRequest) {
        val context = appContext ?: activity?.applicationContext
        if (context == null) {
            pendingRequest = null
            request.result.success("noInstaller")
            return
        }
        committerRunning = true
        executor.execute {
            val outcome = commitSessionOnWorker(context, request)
            mainHandler.post {
                committerRunning = false
                pendingRequest = null
                try {
                    request.result.success(outcome)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun commitSessionOnWorker(
        context: Context,
        request: PendingRequest,
    ): String {
        val apkFile = request.apkFile
        if (!apkFile.exists() || !apkFile.isFile || apkFile.length() <= 0L) {
            return "fileMissing"
        }
        val pm = context.packageManager
        val archiveInfo = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageArchiveInfo(
                    apkFile.path,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageArchiveInfo(apkFile.path, 0)
            }
        } catch (_: Throwable) {
            null
        }
        if (archiveInfo == null || archiveInfo.packageName != context.packageName) {
            return "failed"
        }
        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archiveInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            archiveInfo.versionCode.toLong()
        }
        val expectedVersionCode = if (request.expectedVersionCode > 0L) {
            request.expectedVersionCode
        } else {
            archiveVersionCode
        }

        val packageInstaller = pm.packageInstaller
        val priorId = activeSessionId
        if (priorId != null) {
            try {
                packageInstaller.abandonSession(priorId)
            } catch (_: Throwable) {
            }
            clearActiveSession()
        }
        pruneAbandonedSessions(packageInstaller)

        val size = apkFile.length()
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(context.packageName)
            setSize(size)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(
                    PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED,
                )
            }
        }

        var sessionId = -1
        var session: PackageInstaller.Session? = null
        return try {
            sessionId = packageInstaller.createSession(params)
            session = packageInstaller.openSession(sessionId)
            FileInputStream(apkFile).use { input ->
                session.openWrite("base.apk", 0, size).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                    session.fsync(output)
                }
            }
            val token = UUID.randomUUID().toString()
            activeSessionId = sessionId
            activeToken = token
            activeSessionPath = apkFile.path
            awaitingUserConfirmation = false
            lastConfirmationIntent = null

            SelfUpdateNotifier.writeMarker(
                context = context,
                expectedVersionCode = expectedVersionCode,
                tag = request.tag,
                apkPath = apkFile.path,
                title = request.notificationTitle,
                body = request.notificationBody,
                channelName = request.notificationChannel,
            )

            val statusIntent = Intent(context, ApkInstallStatusReceiver::class.java).apply {
                setPackage(context.packageName)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                sessionId,
                statusIntent,
                pendingFlags,
            )
            session.commit(pendingIntent.intentSender)
            "committed"
        } catch (error: SecurityException) {
            abandonQuietly(packageInstaller, session, sessionId)
            clearActiveSession()
            SelfUpdateNotifier.clearMarker(context)
            "denied"
        } catch (error: IOException) {
            abandonQuietly(packageInstaller, session, sessionId)
            clearActiveSession()
            SelfUpdateNotifier.clearMarker(context)
            if (isStorageFailure(error)) "storage" else "failed"
        } catch (_: Throwable) {
            abandonQuietly(packageInstaller, session, sessionId)
            clearActiveSession()
            SelfUpdateNotifier.clearMarker(context)
            "failed"
        } finally {
            try {
                session?.close()
            } catch (_: Throwable) {
            }
        }
    }

    private fun pruneAbandonedSessions(packageInstaller: PackageInstaller) {
        try {
            val currentId = activeSessionId
            val sessions = packageInstaller.mySessions
                .filter { it.sessionId != currentId }
                .sortedByDescending { it.sessionId }
            for (info in sessions.drop(2)) {
                try {
                    packageInstaller.abandonSession(info.sessionId)
                } catch (_: Throwable) {
                }
            }
        } catch (_: Throwable) {
        }
    }

    private fun abandonQuietly(
        packageInstaller: PackageInstaller,
        session: PackageInstaller.Session?,
        sessionId: Int,
    ) {
        try {
            session?.abandon()
        } catch (_: Throwable) {
            if (sessionId >= 0) {
                try {
                    packageInstaller.abandonSession(sessionId)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun isStorageFailure(error: IOException): Boolean {
        val msg = error.message ?: return false
        return msg.contains("ENOSPC", ignoreCase = true) ||
            msg.contains("No space", ignoreCase = true) ||
            msg.contains("storage", ignoreCase = true)
    }

    fun onInstallStatus(context: Context, intent: Intent) {
        mainHandler.post {
            val token = intent.getStringExtra(EXTRA_TOKEN)
            val currentToken = activeToken
            if (currentToken != null && token != null && token != currentToken) {
                return@post
            }
            val status = intent.getIntExtra(
                PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE,
            )
            when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirmIntent = extractConfirmationIntent(intent)
                    if (confirmIntent == null) {
                        clearActiveSession()
                        SelfUpdateNotifier.clearMarker(context)
                        emitSignal("failed")
                        return@post
                    }
                    lastConfirmationIntent = Intent(confirmIntent)
                    val launched = launchConfirmationIntent(context, confirmIntent)
                    if (!launched) {
                        clearActiveSession()
                        SelfUpdateNotifier.clearMarker(context)
                        emitSignal("failed")
                        return@post
                    }
                    awaitingUserConfirmation = true
                    emitSignal("confirmation")
                }
                PackageInstaller.STATUS_SUCCESS -> {
                    clearActiveSession()
                    emitSignal("succeeded")
                }
                PackageInstaller.STATUS_FAILURE_ABORTED -> {
                    clearActiveSession()
                    SelfUpdateNotifier.clearMarker(context)
                    emitSignal("aborted")
                }
                PackageInstaller.STATUS_FAILURE_STORAGE -> {
                    clearActiveSession()
                    SelfUpdateNotifier.clearMarker(context)
                    emitSignal("storage")
                }
                else -> {
                    clearActiveSession()
                    SelfUpdateNotifier.clearMarker(context)
                    emitSignal("failed")
                }
            }
        }
    }

    private fun extractConfirmationIntent(intent: Intent): Intent? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun launchConfirmationIntent(context: Context, confirmIntent: Intent): Boolean {
        val hostActivity = activity
        return try {
            if (hostActivity != null) {
                hostActivity.startActivity(confirmIntent)
            } else {
                confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(confirmIntent)
            }
            true
        } catch (_: Throwable) {
            try {
                confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(confirmIntent)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    private fun clearActiveSession() {
        activeSessionId = null
        activeToken = null
        activeSessionPath = null
        awaitingUserConfirmation = false
        lastConfirmationIntent = null
    }

    private fun emitSignal(kind: String) {
        try {
            channel?.invokeMethod("status", mapOf("kind" to kind))
        } catch (_: Throwable) {
        }
    }
}
