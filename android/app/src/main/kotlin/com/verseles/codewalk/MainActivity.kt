package com.verseles.codewalk

import android.content.ContentResolver
import android.content.Intent
import android.content.ActivityNotFoundException
import android.app.ActivityManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.browser.customtabs.CustomTabsClient
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.verseles.codewalk.overlay.SessionOverlayService

class MainActivity : FlutterActivity() {
    companion object {
        private const val SYSTEM_SOUNDS_CHANNEL = "codewalk/system_sounds"
        private const val SYSTEM_CHANNEL = "codewalk/system"
        private const val COMPOSER_CLIPBOARD_CHANNEL = "codewalk/composer_clipboard"
        private const val SESSION_OVERLAY_CHANNEL = "codewalk/session_overlay_host"
        private const val SESSION_OVERLAY_ACTIVATION_CHANNEL = "codewalk/session_overlay_activation"
        private const val OAUTH_AUTHORIZATION_REQUEST_CODE = 47021
        private const val OAUTH_FLOW_ID_STATE = "codewalk.oauth.flow_id"

        fun isTrustedOAuthAuthorizationUri(uri: Uri): Boolean =
            uri.scheme == "https" && !uri.host.isNullOrBlank()

        fun buildOAuthCustomTabIntent(uri: Uri, packageName: String): Intent =
            CustomTabsIntent.Builder()
                .setShowTitle(true)
                .build()
                .intent
                .apply {
                    data = uri
                    setPackage(packageName)
                    addCategory(Intent.CATEGORY_BROWSABLE)
                }

        fun buildOAuthExternalBrowserIntent(uri: Uri): Intent =
            Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
    }

    private var sessionOverlayActivationChannel: MethodChannel? = null
    private var systemChannel: MethodChannel? = null
    private var activeOAuthFlowId: String? = null
    private var activityWasRecreated = false
    private var lastTrimMemoryLevel = -1
    private var flutterEngineIdentity = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activityWasRecreated = savedInstanceState != null
        activeOAuthFlowId = savedInstanceState?.getString(OAUTH_FLOW_ID_STATE)
    }

    override fun onTrimMemory(level: Int) {
        lastTrimMemoryLevel = level
        super.onTrimMemory(level)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        activeOAuthFlowId?.let { outState.putString(OAUTH_FLOW_ID_STATE, it) }
        super.onSaveInstanceState(outState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineIdentity = System.identityHashCode(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_SOUNDS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listNotificationSounds" -> result.success(listNotificationSounds())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COMPOSER_CLIPBOARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readContentUri" -> {
                    val rawUri = call.argument<String>("uri")
                    if (rawUri.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        Thread {
                            val payload = try {
                                readClipboardContentUri(rawUri)
                            } catch (_: OutOfMemoryError) {
                                null
                            } catch (_: Exception) {
                                null
                            }
                            runOnUiThread { result.success(payload) }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }

        sessionOverlayActivationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SESSION_OVERLAY_ACTIVATION_CHANNEL,
        )
        dispatchSessionOverlayActivation(intent)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SESSION_OVERLAY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> result.success(requestOverlayPermission())
                "startOverlayService" -> result.success(startSessionOverlayService())
                "stopOverlayService" -> result.success(stopSessionOverlayService())
                "isOverlayServiceRunning" -> result.success(SessionOverlayService.isRunning())
                "updateOverlaySnapshot" -> {
                    @Suppress("UNCHECKED_CAST")
                    val snapshot = call.arguments as? Map<String, Any?>
                    result.success(SessionOverlayService.updateSnapshot(snapshot))
                }
                "consumeOverlayActivation" -> {
                    result.success(sessionOverlayActivationPayload(intent))
                    intent?.removeExtra("session_attention_action")
                }
                "consumeOverlayStopState" -> result.success(consumeOverlayStopState())
                "overlayHeartbeat" -> {
                    SessionOverlayService.noteMainHeartbeat()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_CHANNEL,
        ).also { channel -> channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    startCodeWalkForegroundService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopCodeWalkForegroundService()
                    result.success(true)
                }
                "updateForegroundNotification" -> {
                    val title = call.argument<String>("title") ?: "CodeWalk"
                    val body = call.argument<String>("body")
                        ?: "Reliable background alerts are active"
                    if (CodeWalkForegroundService.isRunning()) {
                        CodeWalkForegroundService.updateContent(this, title, body)
                    } else {
                        startCodeWalkForegroundService(title = title, body = body)
                    }
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestDisableBatteryOptimizations" -> {
                    result.success(requestDisableBatteryOptimizations())
                }
                "getAndroidProcessDiagnostics" -> {
                    result.success(androidProcessDiagnostics())
                }
                "launchOAuthAuthorization" -> {
                    result.success(
                        launchOAuthAuthorization(
                            call.argument<String>("url"),
                            call.argument<String>("flowId"),
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        } }
    }

    private fun androidProcessDiagnostics(): Map<String, Any?> {
        val diagnostics = mutableMapOf<String, Any?>(
            "pid" to android.os.Process.myPid(),
            "activityId" to System.identityHashCode(this),
            "engineId" to flutterEngineIdentity,
            "activityRecreated" to activityWasRecreated,
            "lastTrimMemoryLevel" to lastTrimMemoryLevel,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val activityManager =
                getSystemService(ACTIVITY_SERVICE) as? ActivityManager
            val exitInfo = activityManager
                ?.getHistoricalProcessExitReasons(packageName, 0, 1)
                ?.firstOrNull()
            if (exitInfo != null) {
                diagnostics["lastExitReason"] = exitInfo.reason
                diagnostics["lastExitStatus"] = exitInfo.status
                diagnostics["lastExitImportance"] = exitInfo.importance
                diagnostics["lastExitPssKb"] = exitInfo.pss
                diagnostics["lastExitRssKb"] = exitInfo.rss
                diagnostics["lastExitTimestampEpochMs"] = exitInfo.timestamp
            }
        }
        return diagnostics
    }

    private fun launchOAuthAuthorization(rawUrl: String?, flowId: String?): String? {
        val uri = rawUrl?.let(Uri::parse) ?: return null
        if (!isTrustedOAuthAuthorizationUri(uri) || flowId.isNullOrBlank()) return null

        val customTabsPackage = CustomTabsClient.getPackageName(this, null)
        if (customTabsPackage != null && activeOAuthFlowId == null) {
            try {
                activeOAuthFlowId = flowId
                startActivityForResult(
                    buildOAuthCustomTabIntent(uri, customTabsPackage),
                    OAUTH_AUTHORIZATION_REQUEST_CODE,
                )
                return "custom_tab"
            } catch (_: ActivityNotFoundException) {
                activeOAuthFlowId = null
                // The selected browser disappeared; retry with a normal browser.
            } catch (_: SecurityException) {
                activeOAuthFlowId = null
                // A restricted Custom Tabs provider must not trigger WebView use.
            }
        }

        return try {
            startActivity(buildOAuthExternalBrowserIntent(uri))
            "external_browser"
        } catch (_: ActivityNotFoundException) {
            null
        } catch (_: SecurityException) {
            null
        }
    }

    @Deprecated("Deprecated in Android; retained for the Custom Tab close signal.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OAUTH_AUTHORIZATION_REQUEST_CODE) return
        val flowId = activeOAuthFlowId ?: return
        activeOAuthFlowId = null
        systemChannel?.invokeMethod(
            "oauthAuthorizationClosed",
            mapOf("flowId" to flowId),
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchSessionOverlayActivation(intent)
    }

    private fun readClipboardContentUri(rawUri: String): Map<String, Any?>? {
        val uri = Uri.parse(rawUri)
        if (uri.scheme != ContentResolver.SCHEME_CONTENT) return null

        var displayName: String? = null
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                    displayName = cursor.getString(nameIndex)
                }
            }
        }
        val mimeType = contentResolver.getType(uri)?.lowercase()
        val extension = displayName
            ?.substringAfterLast('.', missingDelimiterValue = "")
            ?.lowercase()
        // Keep these gates aligned with chat_input_external_files.dart. They
        // intentionally run natively so unsupported clipboard data is never read.
        val supportedByName = extension in setOf(
            "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "pdf",
        )
        val supportedByMime = mimeType in setOf(
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "image/bmp",
            "image/heic",
            "image/heif",
            "application/pdf",
        )
        if (!supportedByName && !supportedByMime) return null

        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return null
        return mapOf(
            "name" to displayName,
            "mimeType" to mimeType,
            "bytes" to bytes,
        )
    }

    private fun dispatchSessionOverlayActivation(intent: Intent?) {
        val payload = sessionOverlayActivationPayload(intent) ?: return
        sessionOverlayActivationChannel?.invokeMethod(
            "activation",
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    intent?.removeExtra("session_attention_action")
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
                override fun notImplemented() = Unit
            },
        )
    }

    private fun sessionOverlayActivationPayload(intent: Intent?): Map<String, String?>? {
        if (intent?.hasExtra("session_attention_action") != true) return null
        return mapOf(
            "action" to intent.getStringExtra("session_attention_action"),
            "serverId" to intent.getStringExtra("serverId"),
            "directory" to intent.getStringExtra("directory"),
            "sessionId" to intent.getStringExtra("sessionId"),
            "snapshotId" to intent.getStringExtra("snapshotId"),
        )
    }

    private fun consumeOverlayStopState(): Map<String, Boolean> {
        val preferences = getSharedPreferences("session_attention_native", MODE_PRIVATE)
        val state = mapOf(
            "stoppedByUser" to preferences.getBoolean("stopped_by_user", false),
            "permissionRevoked" to preferences.getBoolean("permission_revoked", false),
        )
        preferences.edit()
            .remove("stopped_by_user")
            .remove("permission_revoked")
            .apply()
        return state
    }

    private fun requestOverlayPermission(): Boolean {
        if (Settings.canDrawOverlays(this)) return true
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun startSessionOverlayService(): Boolean {
        if (!Settings.canDrawOverlays(this)) return false
        return try {
            val intent = Intent(this, SessionOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stopSessionOverlayService(): Boolean {
        return try {
            stopService(Intent(this, SessionOverlayService::class.java))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun startCodeWalkForegroundService(
        title: String? = null,
        body: String? = null,
    ) {
        try {
            val serviceIntent = Intent(this, CodeWalkForegroundService::class.java)
            if (!title.isNullOrBlank()) {
                serviceIntent.putExtra(CodeWalkForegroundService.EXTRA_TITLE, title)
            }
            if (!body.isNullOrBlank()) {
                serviceIntent.putExtra(CodeWalkForegroundService.EXTRA_BODY, body)
            }
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (_: Exception) {
            // No-op: Dart side logs failed calls.
        }
    }

    private fun stopCodeWalkForegroundService() {
        try {
            val serviceIntent = Intent(this, CodeWalkForegroundService::class.java)
            stopService(serviceIntent)
        } catch (_: Exception) {
            // No-op: Dart side logs failed calls.
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        val powerManager = getSystemService(POWER_SERVICE) as? PowerManager
            ?: return false
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestDisableBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return try {
            val powerManager = getSystemService(POWER_SERVICE) as? PowerManager
            val intent = if (
                powerManager != null &&
                    powerManager.isIgnoringBatteryOptimizations(packageName)
            ) {
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            } else {
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun listNotificationSounds(): List<Map<String, String>> {
        val items = mutableListOf<Map<String, String>>()
        val seenSources = mutableSetOf<String>()

        val defaultUri = Settings.System.DEFAULT_NOTIFICATION_URI?.toString()
        if (!defaultUri.isNullOrBlank()) {
            items.add(
                mapOf(
                    "id" to "android_default",
                    "label" to "Android default",
                    "source" to defaultUri,
                )
            )
            seenSources.add(defaultUri)
        }

        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_NOTIFICATION)
        val cursor = manager.cursor ?: return items

        cursor.use {
            while (it.moveToNext()) {
                val title = it.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                val uri = manager.getRingtoneUri(it.position)?.toString()
                if (uri.isNullOrBlank() || seenSources.contains(uri)) {
                    continue
                }
                items.add(
                    mapOf(
                        "id" to "android_${it.position}",
                        "label" to (title ?: "System sound ${it.position + 1}"),
                        "source" to uri,
                    )
                )
                seenSources.add(uri)
            }
        }

        return items
    }
}
