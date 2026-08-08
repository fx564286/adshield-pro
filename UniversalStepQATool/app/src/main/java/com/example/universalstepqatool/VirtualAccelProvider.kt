package com.example.universalstepqatool

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.SystemClock

/**
 * Controlled QA-only cross-app acceleration source.
 * This does NOT inject events into Android SensorManager.
 * Access is restricted by a signature-level permission in AndroidManifest.xml.
 */
class VirtualAccelProvider : ContentProvider() {

    companion object {
        const val AUTHORITY = "com.example.universalstepqatool.qaaccel"
        private val COLUMNS = arrayOf("timestamp_ns", "x", "y", "z", "magnitude", "sequence")
        private const val SAMPLE_PERIOD_MS = 120L
    }

    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val elapsedMs = SystemClock.elapsedRealtime()
        val sequence = elapsedMs / SAMPLE_PERIOD_MS
        val phase = (sequence % 5L).toInt()

        // Walking-like deterministic test waveform, approximately one pulse / 600 ms.
        // Z contains gravity plus the synthetic pulse; X/Y add small orientation-like changes.
        val triple = when (phase) {
            0 -> Triple(0.10, 0.10, 9.81)
            1 -> Triple(1.20, 0.60, 14.74)
            2 -> Triple(-0.70, 0.25, 8.67)
            3 -> Triple(0.45, -0.35, 11.18)
            else -> Triple(0.05, 0.08, 9.81)
        }
        val x = triple.first
        val y = triple.second
        val z = triple.third
        val magnitude = kotlin.math.sqrt(x * x + y * y + z * z)

        return MatrixCursor(COLUMNS, 1).apply {
            addRow(
                arrayOf(
                    SystemClock.elapsedRealtimeNanos(),
                    x,
                    y,
                    z,
                    magnitude,
                    sequence
                )
            )
        }
    }

    override fun getType(uri: Uri): String = "vnd.android.cursor.item/vnd.universalstepqa.accel"

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
