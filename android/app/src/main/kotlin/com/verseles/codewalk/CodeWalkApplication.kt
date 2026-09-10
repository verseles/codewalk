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
        // MainActivity is not the only entry point: WorkManager's background
        // engine, the overlay service and the foreground service all start
        // Dart without an Activity. Application.onCreate covers every one of
        // them before the first channel call.
        curePoisonedLargeCachePreferences(this)
    }

    companion object {
        private const val TAG = "CodeWalkPrefsCure"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_KEY_PREFIX = "flutter."

        // Mirrors the Dart ChatCachePayloadLimits policy. Generic
        // large-payload families use the preferences ceiling; the composer
        // draft family uses the higher payload ceiling so a 1-2MB legacy
        // draft can still be migrated to the file-backed store by Dart
        // instead of being destroyed here (draft text is user data that SWR
        // cannot regenerate).
        private const val MAX_PREFS_VALUE_CHARS = 1024 * 1024
        private const val MAX_DRAFT_VALUE_CHARS = 2 * 1024 * 1024

        private const val DRAFT_KEY_BASE = "session_composer_draft"

        private val LARGE_KEY_BASES = listOf(
            "cached_sessions",
            "last_session_snapshot",
            "session_messages_snapshot",
            "selection_blob_v1",
            DRAFT_KEY_BASE,
        )

        private fun matchedLargeKeyBase(rawKey: String): String? {
            val key = if (rawKey.startsWith(FLUTTER_KEY_PREFIX)) {
                rawKey.substring(FLUTTER_KEY_PREFIX.length)
            } else {
                rawKey
            }
            return LARGE_KEY_BASES.firstOrNull { base ->
                key == base || key.startsWith("$base::")
            }
        }

        private fun maxCharsForBase(base: String): Int =
            if (base == DRAFT_KEY_BASE) {
                MAX_DRAFT_VALUE_CHARS
            } else {
                MAX_PREFS_VALUE_CHARS
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
                val all = prefs.all
                var candidates = 0
                val doomed = mutableListOf<Pair<String, Int>>()
                for ((key, value) in all) {
                    val base = matchedLargeKeyBase(key) ?: continue
                    candidates += 1
                    if (value is String &&
                        value.length > maxCharsForBase(base)
                    ) {
                        doomed.add(key to value.length)
                    }
                }
                if (doomed.isEmpty()) {
                    Log.i(
                        TAG,
                        "scan complete: entries=${all.size} " +
                            "candidates=$candidates quarantined=0",
                    )
                    return
                }
                val editor = prefs.edit()
                for ((key, chars) in doomed) {
                    Log.w(TAG, "quarantined key=$key chars=$chars")
                    editor.remove(key)
                }
                // Synchronous commit: the file must be clean before any
                // plugin calls getAll(). Only small entries are rewritten.
                val committed = editor.commit()
                Log.i(
                    TAG,
                    "scan complete: entries=${all.size} " +
                        "candidates=$candidates " +
                        "quarantined=${doomed.size} commit=$committed",
                )
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
