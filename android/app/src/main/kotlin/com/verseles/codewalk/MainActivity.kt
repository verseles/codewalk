package com.verseles.codewalk

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // A/B for release-only frame-presentation stall (theme/task/progress
    // freeze): TextureView composes inside the Activity window instead of a
    // dedicated SurfaceView/BLAST queue. Revert to default (surface) by
    // deleting this override if it regresses.
    override fun getRenderMode(): RenderMode = RenderMode.texture

    private var pairingChannel: MethodChannel? = null
    private val pendingPairing = ArrayDeque<Pair<Int, String>>()
    private var pairingSequence = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Defense in depth: the Application cure already ran, but an
        // edge-case process could theoretically reach here first.
        CodeWalkApplication.curePoisonedLargeCachePreferences(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capturePairingIntent(intent)
        pairingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.verseles.codewalk/v2-pairing").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPending" -> result.success(pendingPairing.firstOrNull()?.let {
                        mapOf("id" to it.first, "uri" to it.second)
                    })
                    "ack" -> {
                        val id = (call.arguments as? Number)?.toInt()
                        pendingPairing.removeAll { it.first == id }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePairingIntent(intent)
        pairingChannel?.invokeMethod("pending", null)
    }

    override fun getInitialRoute(): String = "/"

    private fun capturePairingIntent(incoming: Intent?) {
        val uri = incoming?.data ?: return
        if (uri.scheme != "codewalk" || uri.host != "pair") return
        val raw = uri.toString()
        if (raw.length > 4096 || pendingPairing.size >= 4) return
        pendingPairing.addLast(Pair(++pairingSequence, raw))
        incoming.data = null
    }
}
