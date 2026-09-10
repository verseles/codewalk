package com.verseles.codewalk

import android.app.Application
import android.content.Context
import android.util.Log

/**
 * Quarantines oversized legacy chat-cache payloads left in
 * `FlutterSharedPreferences.xml` before any Flutter engine starts.
 *
 * A ~140MB string once stored there killed the app on every launch: the
 * value crosses the platform channel inside
 * `StandardMessageCodec.encodeMessage`, which OOMs in engine code that Dart
 * cannot catch. Removing the poisoned keys natively (key names only, values
 * never cross a channel here) cures already-affected installs without root
 * or data wipe. Snapshots are regenerable from the server via SWR.
 *
 * Keep [LARGE_KEY_BASES] aligned with `_isLargeCachePayloadPreferenceKey`
 * in `app_local_datasource_storage_helpers.dart`.
 */
class CodeWalkApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        curePoisonedLargeCachePreferences(this)
    }

    companion object {
        private const val TAG = "CodeWalkPrefsCure"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_KEY_PREFIX = "flutter."

        // Mirrors the Dart ChatCachePayloadLimits.maxPrefsChars policy.
        private const val MAX_PREFS_VALUE_CHARS = 1024 * 1024

        private val LARGE_KEY_BASES = listOf(
            "cached_sessions",
            "last_session_snapshot",
            "session_messages_snapshot",
            "selection_blob_v1",
        )

        private fun isLargeCacheKey(rawKey: String): Boolean {
            val key = if (rawKey.startsWith(FLUTTER_KEY_PREFIX)) {
                rawKey.substring(FLUTTER_KEY_PREFIX.length)
            } else {
                rawKey
            }
            return LARGE_KEY_BASES.any { base ->
                key == base || key.startsWith("$base::")
            }
        }

        fun curePoisonedLargeCachePreferences(context: Context) {
            try {
                // Runs in a fresh process with a near-empty heap, before any
                // Flutter engine exists. Parsing the XML here is safe: the
                // historical crash happened later, in the channel codec, only
                // after the parse had already succeeded.
                val prefs = context.getSharedPreferences(
                    FLUTTER_PREFS,
                    Context.MODE_PRIVATE,
                )
                val doomed = prefs.all.mapNotNull { (key, value) ->
                    if (isLargeCacheKey(key) &&
                        value is String &&
                        value.length > MAX_PREFS_VALUE_CHARS
                    ) {
                        key
                    } else {
                        null
                    }
                }
                if (doomed.isEmpty()) {
                    return
                }
                val editor = prefs.edit()
                doomed.forEach { editor.remove(it) }
                // Synchronous commit: the file must be clean before any
                // plugin calls getAll(). Only small entries are rewritten.
                val committed = editor.commit()
                Log.w(TAG, "Quarantined ${doomed.size} oversized cache keys (commit=$committed)")
            } catch (t: Throwable) {
                try {
                    Log.w(TAG, "Prefs cure failed: ${t.message}")
                } catch (_: Throwable) {
                    // Never crash process startup for diagnostics.
                }
            }
        }
    }
}
