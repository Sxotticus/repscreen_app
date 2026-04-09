package com.pushscroll.pushscroll_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.repscreen/blocking"
    private val SOUND_CHANNEL = "com.repscreen/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Blocking method channel (existing) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())

                    "hasUsagePermission" -> result.success(hasUsagePermission())
                    "requestUsagePermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }

                    "hasOverlayPermission" ->
                        result.success(Settings.canDrawOverlays(this))
                    "requestOverlayPermission" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }

                    "startBlocking" -> {
                        val secs = call.argument<Int>("seconds") ?: 0
                        val apps =
                            call.argument<List<String>>("apps") ?: listOf()
                        val intent =
                            Intent(this, ScreenTimeService::class.java).apply {
                                action = "START"
                                putExtra("seconds", secs)
                                putStringArrayListExtra(
                                    "blocked", ArrayList(apps)
                                )
                            }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    }

                    "stopBlocking" -> {
                        startService(
                            Intent(this, ScreenTimeService::class.java)
                                .apply { action = "STOP" }
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ── Sound method channel (new) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSound" -> {
                        val type = call.argument<String>("type") ?: ""
                        playSound(type)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /* ── Sound Generation ── */

    private fun playSound(type: String) {
        Thread {
            try {
                when (type) {
                    "repTick" -> playTone(880.0, 60, 0.4f)
                    "setComplete" -> playChord(
                        listOf(
                            Triple(523.0, 0, 150),   // C5
                            Triple(659.0, 80, 150),   // E5
                            Triple(784.0, 160, 200)   // G5
                        ), 0.45f
                    )
                    "timerWarning" -> {
                        playTone(600.0, 120, 0.5f)
                        Thread.sleep(100)
                        playTone(600.0, 120, 0.5f)
                    }
                    "timerExpired" -> playChord(
                        listOf(
                            Triple(800.0, 0, 180),
                            Triple(700.0, 220, 180),
                            Triple(600.0, 440, 250)
                        ), 0.55f
                    )
                    "milestone" -> playChord(
                        listOf(
                            Triple(523.0, 0, 120),    // C5
                            Triple(659.0, 100, 120),  // E5
                            Triple(784.0, 200, 120),  // G5
                            Triple(1047.0, 300, 280)  // C6
                        ), 0.45f
                    )
                    "countdownTick" -> playTone(1000.0, 30, 0.25f)
                }
            } catch (_: Exception) {}
        }.start()
    }

    /** Play a single sine-wave tone */
    private fun playTone(freq: Double, durationMs: Int, volume: Float) {
        val sr = 44100
        val n = (sr * durationMs / 1000.0).toInt()
        val samples = ShortArray(n)

        for (i in 0 until n) {
            val t = i.toDouble() / sr
            var s = sin(2.0 * PI * freq * t)

            // Fade envelope to avoid clicks
            val fadeIn = min(i / (sr * 0.005), 1.0)
            val fadeOut = min((n - i) / (sr * 0.01), 1.0)
            s *= fadeIn * fadeOut * volume

            samples[i] = (s * Short.MAX_VALUE).toInt().toShort()
        }

        writeAndPlay(samples, sr)
    }

    /** Play a sequence of tones (arpeggio/chord) with timing offsets */
    private fun playChord(
        notes: List<Triple<Double, Int, Int>>,  // freq, offsetMs, durationMs
        volume: Float
    ) {
        val sr = 44100
        val totalMs = notes.maxOf { it.second + it.third }
        val totalSamples = (sr * totalMs / 1000.0).toInt()
        val mixed = FloatArray(totalSamples)

        for ((freq, offsetMs, durMs) in notes) {
            val offsetSamp = (sr * offsetMs / 1000.0).toInt()
            val durSamp = (sr * durMs / 1000.0).toInt()

            for (i in 0 until durSamp) {
                val idx = offsetSamp + i
                if (idx >= totalSamples) break
                val t = i.toDouble() / sr
                var s = sin(2.0 * PI * freq * t)

                val fadeIn = min(i / (sr * 0.005), 1.0)
                val fadeOut = min((durSamp - i) / (sr * 0.015), 1.0)
                s *= fadeIn * fadeOut

                mixed[idx] += (s * volume).toFloat()
            }
        }

        val samples = ShortArray(totalSamples)
        for (i in mixed.indices) {
            val clamped = mixed[i].coerceIn(-1f, 1f)
            samples[i] = (clamped * Short.MAX_VALUE).toInt().toShort()
        }

        writeAndPlay(samples, sr)
    }

    /** Write samples to an AudioTrack and play */
    private fun writeAndPlay(samples: ShortArray, sampleRate: Int) {
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuf, samples.size * 2))
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.write(samples, 0, samples.size)
        track.play()

        // Wait for playback to finish, then release
        val durationMs = (samples.size * 1000L / sampleRate) + 80
        Thread.sleep(durationMs)
        track.stop()
        track.release()
    }

    /* ── helpers ── */

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent =
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map {
                mapOf(
                    "package" to it.activityInfo.packageName,
                    "name" to it.loadLabel(pm).toString()
                )
            }
            .filter { it["package"] != packageName }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps =
            getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(), packageName
        ) == AppOpsManager.MODE_ALLOWED
    }
}
