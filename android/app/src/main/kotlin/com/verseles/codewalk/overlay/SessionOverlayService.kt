package com.verseles.codewalk.overlay

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowInsets
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.eyedeadevelopment.fluttertts.FlutterTtsPlugin
import com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin
import com.verseles.codewalk.MainActivity
import com.verseles.codewalk.R
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import kotlin.math.roundToInt
import xyz.luan.audioplayers.AudioplayersPlugin

class SessionOverlayService : Service() {
    companion object {
        private const val CHANNEL_ID = "codewalk_session_attention_overlay_v1"
        private const val SERVICE_CHANNEL = "codewalk/session_overlay_service"
        private const val NOTIFICATION_ID = 9801
        private const val ACTION_STOP = "com.verseles.codewalk.overlay.STOP"
        private const val ACTION_OPEN = "com.verseles.codewalk.overlay.OPEN"
        // Floor for the scaled Bubble so the touch target never becomes
        // unusable at the smallest setting.
        private const val MIN_BUBBLE_DP = 56
        private const val BUBBLE_WIDTH_DP = 96
        private const val BUBBLE_HEIGHT_DP = 96
        private const val PANEL_WIDTH_DP = 360
        private const val PANEL_HEIGHT_DP = 240
        private const val OVERLAY_EDGE_MARGIN_DP = 16
        private const val FIRST_FRAME_TIMEOUT_MS = 5_000L
        private const val TAG = "SessionOverlay"

        @Volatile
        private var instance: SessionOverlayService? = null
        @Volatile
        private var lastMainHeartbeatEpochMs: Long = 0
        @Volatile
        private var disableSecureForTest = false

        fun isRunning(): Boolean = instance != null
        fun hasAttachedOverlay(): Boolean = instance?.flutterView != null
        fun hasRenderedFirstFrameForTest(): Boolean =
            instance?.flutterView?.hasRenderedFirstFrame() == true
        fun currentOverlaySizeForTest(): Pair<Int, Int>? =
            instance?.flutterView?.layoutParams
                ?.let { it as? WindowManager.LayoutParams }
                ?.let { it.width to it.height }
        fun currentOverlayFlagsForTest(): Int? =
            instance?.flutterView?.layoutParams
                ?.let { it as? WindowManager.LayoutParams }
                ?.flags
        fun currentMovementBoundsForTest(): Rect? =
            instance?.overlayMovementBounds()?.let(::Rect)
        fun currentOverlayRectForTest(): Rect? {
            val view = instance?.flutterView ?: return null
            val params = view.layoutParams as? WindowManager.LayoutParams ?: return null
            val location = IntArray(2)
            view.getLocationOnScreen(location)
            val width = view.width.takeIf { it > 0 } ?: params.width
            val height = view.height.takeIf { it > 0 } ?: params.height
            return Rect(
                location[0],
                location[1],
                location[0] + width,
                location[1] + height,
            )
        }
        fun setDisableSecureForTest(context: Context, disable: Boolean) {
            check(isDebuggable(context)) {
                "Secure overlay capture can only be changed in debug builds"
            }
            disableSecureForTest = disable
        }
        private fun isDebuggable(context: Context): Boolean =
            context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        fun currentSnapshotRevision(): Long = instance?.currentRevision ?: -1
        fun dispatchNullStartForTest(): Int? =
            instance?.onStartCommand(null, 0, 0)

        fun expireMainHeartbeatForTest() {
            lastMainHeartbeatEpochMs = 0
        }

        fun applyFallbackSnapshotForTest(snapshot: Map<String, Any?>): Boolean =
            instance?.applyFallbackSnapshot(snapshot) ?: false
        fun applyLocalSnapshotForTest(snapshot: Map<String, Any?>): Boolean =
            instance?.applyLocalSnapshot(snapshot) ?: false

        fun noteMainHeartbeat() {
            lastMainHeartbeatEpochMs = System.currentTimeMillis()
        }

        fun isMainProducerAlive(): Boolean =
            System.currentTimeMillis() - lastMainHeartbeatEpochMs < 15_000L

        fun updateSnapshot(snapshot: Map<String, Any?>?): Boolean {
            val service = instance ?: return false
            snapshot ?: return false
            service.applySnapshot(snapshot)
            return true
        }
    }

    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null

    // Linear factor for the Bubble, delivered with each snapshot (#132).
    private var bubbleScale = 0.7f
    private var serviceChannel: MethodChannel? = null
    private var currentSnapshot: Map<String, Any?>? = null
    private var currentGeneration: String? = null
    private var currentRevision: Long = -1
    private var currentProducer: String? = null
    private var stoppingForNativeReason = false
    private var nativeStopFinalized = false
    private var persistOffTimeout: Runnable? = null
    private var firstFrameTimeout: Runnable? = null
    private var firstFrameLayoutListener: View.OnLayoutChangeListener? = null
    private lateinit var windowManager: WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> detachOverlay()
                Intent.ACTION_USER_PRESENT -> currentSnapshot?.let(::renderSnapshot)
            }
        }
    }
    private val permissionCheck = object : Runnable {
        override fun run() {
            if (!Settings.canDrawOverlays(this@SessionOverlayService)) {
                detachOverlay()
                stopForNativeReason("permission_revoked")
                return
            }
            handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startAsForeground(null)
        instance = this
        ContextCompat.registerReceiver(
            this,
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        handler.post(permissionCheck)
        if (Settings.canDrawOverlays(this)) {
            startFlutterEngine()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForNativeReason("stopped_by_user")
                return START_NOT_STICKY
            }
            ACTION_OPEN -> {
                openMainActivity(intent.extras?.keySet()?.associateWith { intent.extras?.get(it) })
                return START_STICKY
            }
        }
        if (!Settings.canDrawOverlays(this)) {
            stopForNativeReason("permission_revoked")
            return START_NOT_STICKY
        }
        if (engine == null) {
            startFlutterEngine()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        currentSnapshot?.let(::renderSnapshot)
    }

    override fun onDestroy() {
        instance = null
        handler.removeCallbacks(permissionCheck)
        persistOffTimeout?.let(handler::removeCallbacks)
        persistOffTimeout = null
        runCatching { unregisterReceiver(screenReceiver) }
        detachOverlay()
        serviceChannel?.setMethodCallHandler(null)
        serviceChannel = null
        engine?.let { flutterEngine ->
            flutterEngine.serviceControlSurface.detachFromService()
            flutterEngine.destroy()
        }
        engine = null
        disableSecureForTest = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun stopForNativeReason(reasonKey: String) {
        getSharedPreferences("session_attention_native", MODE_PRIVATE)
            .edit().putBoolean(reasonKey, true).apply()
        if (stoppingForNativeReason) return
        stoppingForNativeReason = true
        handler.removeCallbacks(permissionCheck)
        val channel = serviceChannel
        if (channel == null) {
            stopSelf()
            return
        }
        val finish = {
            if (!nativeStopFinalized) {
                nativeStopFinalized = true
                persistOffTimeout?.let(handler::removeCallbacks)
                persistOffTimeout = null
                stopSelf()
            }
        }
        persistOffTimeout = Runnable { finish() }.also {
            handler.postDelayed(it, 1_500L)
        }
        channel.invokeMethod(
            "persistPresentationOff",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) = finish()
                override fun error(code: String, message: String?, details: Any?) = finish()
                override fun notImplemented() = finish()
            },
        )
    }

    private fun startFlutterEngine() {
        if (engine != null || !Settings.canDrawOverlays(this)) return
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val flutterEngine = FlutterEngine(applicationContext, null, false, false)
        flutterEngine.plugins.add(AudioplayersPlugin())
        flutterEngine.plugins.add(FlutterSecureStoragePlugin())
        flutterEngine.plugins.add(FlutterTtsPlugin())
        // NOTE: path_provider_android 2.3+ is Dart/JNI-only (no registrant
        // class); it self-registers through the Dart plugin registrant that
        // the engine runs for this isolate.
        flutterEngine.plugins.add(SharedPreferencesPlugin())
        flutterEngine.serviceControlSurface.attachToService(this, null, true)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "command" -> {
                    @Suppress("UNCHECKED_CAST")
                    handleCommand(call.arguments as? Map<String, Any?>)
                    result.success(true)
                }
                "requestFullSnapshot" -> {
                    currentSnapshot?.let { channel.invokeMethod("applySnapshot", it) }
                    result.success(true)
                }
                "restoreSnapshot" -> {
                    @Suppress("UNCHECKED_CAST")
                    val snapshot = call.arguments as? Map<String, Any?>
                    if (snapshot == null) {
                        result.success(false)
                    } else {
                        applySnapshot(snapshot)
                        result.success(true)
                    }
                }
                "applyLocalState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val snapshot = call.arguments as? Map<String, Any?>
                    if (snapshot == null) {
                        result.success(false)
                    } else {
                        result.success(applyLocalSnapshot(snapshot))
                    }
                }
                "applyFallbackState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val snapshot = call.arguments as? Map<String, Any?>
                    result.success(snapshot != null && applyFallbackSnapshot(snapshot))
                }
                "stopLocal" -> {
                    getSharedPreferences("session_attention_native", MODE_PRIVATE)
                        .edit().putBoolean("stopped_by_user", true).apply()
                    stopSelf()
                    result.success(true)
                }
                "isMainProducerAlive" -> result.success(isMainProducerAlive())
                else -> result.notImplemented()
            }
        }
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                "package:codewalk/presentation/services/session_attention/session_overlay_entrypoint.dart",
                "sessionOverlayAndroidMain",
            ),
        )
        engine = flutterEngine
        serviceChannel = channel
        currentSnapshot?.let { channel.invokeMethod("applySnapshot", it) }
    }

    private fun applySnapshot(snapshot: Map<String, Any?>) {
        val generation = snapshot["generation"] as? String ?: ""
        val revision = (snapshot["revision"] as? Number)?.toLong() ?: 0L
        val full = snapshot["fullResynchronization"] as? Boolean ?: false
        val producer = snapshot["producer"] as? String ?: "main"
        if (producer == "restore" && currentProducer == "main") return
        val liveHandoff = currentProducer == "restore" && producer == "main"
        if (!liveHandoff && currentGeneration == generation && revision <= currentRevision) return
        if (!liveHandoff && currentGeneration != null && currentGeneration != generation && !full) return
        if (producer == "main") noteMainHeartbeat()
        val acceptedSnapshot = if (liveHandoff && !full) {
            snapshot.toMutableMap().apply { this["fullResynchronization"] = true }
        } else {
            snapshot
        }
        currentGeneration = generation
        currentRevision = revision
        currentProducer = producer
        currentSnapshot = acceptedSnapshot

        renderSnapshot(acceptedSnapshot)
    }

    private fun applyFallbackSnapshot(snapshot: Map<String, Any?>): Boolean {
        if (isMainProducerAlive()) return false
        currentSnapshot = snapshot
        renderSnapshot(snapshot)
        return true
    }

    private fun applyLocalSnapshot(snapshot: Map<String, Any?>): Boolean {
        val generation = snapshot["generation"] as? String ?: return false
        val revision = (snapshot["revision"] as? Number)?.toLong() ?: return false
        if (generation != currentGeneration || revision != currentRevision) return false
        currentSnapshot = snapshot
        renderSnapshot(snapshot)
        return true
    }

    private fun renderSnapshot(snapshot: Map<String, Any?>) {

        if (!Settings.canDrawOverlays(this)) {
            stopForNativeReason("permission_revoked")
            return
        }
        bubbleScale = (snapshot["bubbleScale"] as? Number)?.toFloat()?.coerceIn(0.3f, 1.5f)
            ?: bubbleScale
        val presentation = snapshot["presentation"] as? String ?: "off"
        @Suppress("UNCHECKED_CAST")
        val items = snapshot["items"] as? List<Map<String, Any?>> ?: emptyList()
        if (presentation == "off") {
            stopSelf()
            return
        }
        val keyguard = getSystemService(KeyguardManager::class.java)
        // The external overlay exists to follow work while the user is away
        // from CodeWalk. With the app itself on screen it would only cover the
        // real thing, so it steps aside and comes back on backgrounding (#128).
        val appInForeground = snapshot["appInForeground"] as? Boolean ?: false
        if (items.isEmpty() || appInForeground || keyguard?.isDeviceLocked == true) {
            detachOverlay()
        } else {
            attachOrResizeOverlay(presentation)
        }
        startAsForeground(items.firstOrNull())
        serviceChannel?.invokeMethod("applySnapshot", snapshot)
    }

    private fun attachOrResizeOverlay(presentation: String) {
        val bounds = overlayMovementBounds()
        val (width, height) = overlaySize(presentation, bounds)
        val existing = flutterView
        if (existing != null) {
            val params = existing.layoutParams as WindowManager.LayoutParams
            params.width = width
            params.height = height
            clampToDisplay(params)
            windowManager.updateViewLayout(existing, params)
            return
        }
        val flutterEngine = engine ?: return
        val surfaceView = FlutterSurfaceView(this, true)
        val view = FlutterView(this, surfaceView)
        val saved = getSharedPreferences("session_attention_native", MODE_PRIVATE)
        var windowFlags =
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (!isDebuggable(this) || !disableSecureForTest) {
            windowFlags = windowFlags or WindowManager.LayoutParams.FLAG_SECURE
        }
        val params = WindowManager.LayoutParams(
            width,
            height,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            windowFlags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = if (saved.contains("x_fraction")) {
                bounds.left + ((bounds.width() - width) * saved.getFloat("x_fraction", 1f)).toInt()
            } else {
                bounds.right - width
            }
            y = if (saved.contains("y_fraction")) {
                bounds.top + ((bounds.height() - height) * saved.getFloat("y_fraction", .15f)).toInt()
            } else {
                bounds.top + dp(BUBBLE_HEIGHT_DP)
            }
        }
        clampToDisplay(params)
        configureDrag(view, params)
        windowManager.addView(view, params)
        flutterView = view
        view.attachToFlutterEngine(flutterEngine)
        // A FlutterEngine hosted by a Service never receives an Activity
        // lifecycle, so without this it stays un-resumed and the framework
        // ignores pointer events: taps on Open, Read and Dismiss did nothing
        // (#131). The drag listener was never the culprit.
        flutterEngine.lifecycleChannel.appIsResumed()
        scheduleFirstFrameTimeout(view)
    }

    private fun clampToDisplay(params: WindowManager.LayoutParams) {
        val bounds = overlayMovementBounds()
        params.x = params.x.coerceIn(bounds.left, (bounds.right - params.width).coerceAtLeast(bounds.left))
        params.y = params.y.coerceIn(bounds.top, (bounds.bottom - params.height).coerceAtLeast(bounds.top))
    }

    private fun overlaySize(presentation: String, bounds: Rect): Pair<Int, Int> {
        val isPanel = presentation == "panel"
        // Only the Bubble scales; the Panel keeps its fixed dimensions so its
        // summary layout stays legible at every setting (#132).
        val scale = if (isPanel) 1f else bubbleScale
        val widthDp = if (isPanel) PANEL_WIDTH_DP else BUBBLE_WIDTH_DP
        val heightDp = if (isPanel) PANEL_HEIGHT_DP else BUBBLE_HEIGHT_DP
        val scaledWidthDp = (widthDp * scale).toInt().coerceAtLeast(MIN_BUBBLE_DP)
        val scaledHeightDp = (heightDp * scale).toInt().coerceAtLeast(MIN_BUBBLE_DP)
        val width = dp(scaledWidthDp).coerceAtMost(bounds.width().coerceAtLeast(1))
        val height = dp(scaledHeightDp).coerceAtMost(bounds.height().coerceAtLeast(1))
        return width to height
    }

    private fun overlayMovementBounds(): Rect {
        val bounds = availableBounds()
        val desiredMargin = dp(OVERLAY_EDGE_MARGIN_DP)
        val horizontalMargin = desiredMargin.coerceAtMost(
            ((bounds.width() - 1).coerceAtLeast(0)) / 2,
        )
        val verticalMargin = desiredMargin.coerceAtMost(
            ((bounds.height() - 1).coerceAtLeast(0)) / 2,
        )
        bounds.inset(horizontalMargin, verticalMargin)
        return bounds
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).roundToInt()

    private fun availableBounds(): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val bounds = Rect(metrics.bounds)
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            bounds.left += insets.left
            bounds.top += insets.top
            bounds.right -= insets.right
            bounds.bottom -= insets.bottom
            return bounds
        }
        @Suppress("DEPRECATION")
        return Rect(0, 0, resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels)
    }

    private fun configureDrag(view: FlutterView, params: WindowManager.LayoutParams) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragging = false
                    logTouch("down")
                    false
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - downRawX
                    val deltaY = event.rawY - downRawY
                    if (!dragging && kotlin.math.hypot(deltaX.toDouble(), deltaY.toDouble()) > touchSlop) {
                        dragging = true
                    }
                    if (dragging) {
                        params.x = startX + deltaX.toInt()
                        params.y = startY + deltaY.toInt()
                        clampToDisplay(params)
                        windowManager.updateViewLayout(view, params)
                        true
                    } else {
                        false
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    logTouch(if (dragging) "up-drag" else "up-tap")
                    if (dragging) {
                        persistBounds(params)
                        true
                    } else {
                        false
                    }
                }
                else -> false
            }
        }
    }

    // Traces the overlay touch path so a tap that produces no action can be
    // told apart from one that never arrived (#131). Debug builds only.
    private fun logTouch(phase: String) {
        if (isDebuggable(this)) {
            Log.d(TAG, "overlay touch phase=" + phase)
        }
    }

    private fun persistBounds(params: WindowManager.LayoutParams) {
        val bounds = overlayMovementBounds()
        val maxX = (bounds.width() - params.width).coerceAtLeast(1)
        val maxY = (bounds.height() - params.height).coerceAtLeast(1)
        val xFraction = ((params.x - bounds.left).toFloat() / maxX).coerceIn(0f, 1f)
        val yFraction = ((params.y - bounds.top).toFloat() / maxY).coerceIn(0f, 1f)
        getSharedPreferences("session_attention_native", MODE_PRIVATE).edit()
            .putFloat("x_fraction", xFraction)
            .putFloat("y_fraction", yFraction)
            .apply()
    }

    private fun detachOverlay() {
        firstFrameTimeout?.let(handler::removeCallbacks)
        firstFrameTimeout = null
        engine?.lifecycleChannel?.appIsPaused()
        flutterView?.let { view ->
            firstFrameLayoutListener?.let(view::removeOnLayoutChangeListener)
            view.detachFromFlutterEngine()
            runCatching { windowManager.removeViewImmediate(view) }
        }
        firstFrameLayoutListener = null
        flutterView = null
    }

    private fun scheduleFirstFrameTimeout(view: FlutterView) {
        fun armTimeout() {
            firstFrameTimeout?.let(handler::removeCallbacks)
            firstFrameTimeout = Runnable {
                firstFrameTimeout = null
                if (flutterView === view && !view.hasRenderedFirstFrame()) {
                    Log.w(TAG, "Session overlay removed: first frame timeout")
                    detachOverlay()
                }
            }.also { handler.postDelayed(it, FIRST_FRAME_TIMEOUT_MS) }
        }

        firstFrameLayoutListener?.let(view::removeOnLayoutChangeListener)
        firstFrameLayoutListener = null
        armTimeout()
        if (view.width > 0 && view.height > 0) return

        firstFrameLayoutListener = object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                changedView: View,
                left: Int,
                top: Int,
                right: Int,
                bottom: Int,
                oldLeft: Int,
                oldTop: Int,
                oldRight: Int,
                oldBottom: Int,
            ) {
                if (right <= left || bottom <= top) return
                changedView.removeOnLayoutChangeListener(this)
                firstFrameLayoutListener = null
                if (flutterView === view && !view.hasRenderedFirstFrame()) {
                    armTimeout()
                } else {
                    firstFrameTimeout?.let(handler::removeCallbacks)
                    firstFrameTimeout = null
                }
            }
        }.also(view::addOnLayoutChangeListener)
    }

    private fun handleCommand(command: Map<String, Any?>?) {
        when (command?.get("action") as? String) {
            "stop" -> {
                openMainActivity(command)
                stopSelf()
            }
            "open" -> openMainActivity(command)
        }
    }

    private fun openMainActivity(payload: Map<String, Any?>?) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("session_attention_action", payload?.get("action") as? String ?: "open")
            putExtra("serverId", payload?.get("serverId") as? String)
            putExtra("directory", payload?.get("directory") as? String)
            putExtra("sessionId", payload?.get("sessionId") as? String)
            putExtra("snapshotId", payload?.get("snapshotId") as? String)
        }
        startActivity(intent)
    }

    private fun startAsForeground(primary: Map<String, Any?>?) {
        val openIntent = Intent(this, SessionOverlayService::class.java).apply {
            action = ACTION_OPEN
            primary?.let {
                putExtra("serverId", (it["identity"] as? Map<*, *>)?.get("serverId") as? String)
                putExtra("directory", (it["identity"] as? Map<*, *>)?.get("directory") as? String)
                putExtra("sessionId", (it["identity"] as? Map<*, *>)?.get("sessionId") as? String)
                putExtra("snapshotId", it["snapshotId"] as? String)
            }
        }
        val openAction = PendingIntent.getService(
            this,
            99,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(this, SessionOverlayService::class.java).apply { action = ACTION_STOP }
        val stopAction = PendingIntent.getService(
            this,
            98,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_codewalk)
            .setContentTitle("CodeWalk session overlay")
            .setContentText("Session attention overlay is active")
            .setContentIntent(openAction)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(0, "Open CodeWalk", openAction)
            .addAction(0, "Stop overlay", stopAction)
            .build()
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            },
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Session attention overlay",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }
}
