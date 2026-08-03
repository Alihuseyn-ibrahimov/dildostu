package com.dildostu.dildostu

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Fon rutin toplamasının (WorkManager) etibarlı işləməsi üçün Android-in
// batareya optimallaşdırmasından (Doze) istisna olmaq lazımdır — əks halda
// bəzi istehsalçılar (Samsung, Xiaomi) proqram bağlı olanda fon tapşırığını
// öldürür və geofence bildirişi heç vaxt gəlmir.
private const val BATTERY_CHANNEL = "dildostu/battery"

// Build "flavor" (direct/play) — main.dart bunu oxuyub Google Play
// buraxılışında self-update/arxa-fon-məkan UI-larını gizlədir (bax
// android/app/src/play/AndroidManifest.xml-dəki meta-data).
private const val BUILD_CHANNEL = "dildostu/build_flavor"
private const val META_IS_PLAY_BUILD = "dildostu.isPlayBuild"

// Brauzerdə keçid açmaq üçün (məxfilik siyasəti). `url_launcher` paketi
// bu maşında pub-cache/antivirus toqquşması səbəbindən qurulmurdu (eyni
// problem əvvəllər workmanager_android/open_filex-də də olub) — ona görə
// native Intent birbaşa işlədilir, əlavə plugin lazım deyil.
private const val BROWSER_CHANNEL = "dildostu/browser"

// Səsli kitab plyeri. `just_audio` kimi federated plugin İŞLƏDİLMİR — bu
// maşında pub-cache/Gradle problemi artıq üç dəfə buildi sındırıb
// (url_launcher_android, workmanager_android, open_filex). Native
// MediaPlayer səthi kiçikdir (6 metod) və həmin riski daşımır.
private const val AUDIO_CHANNEL = "dildostu/audio"

class MainActivity : FlutterActivity() {
    private var audioPlayer: MediaPlayer? = null
    private var audioPrepared = false
    private var audioCompleted = false
    private var audioError: String? = null

    private fun releaseAudio() {
        audioPlayer?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // Hazır olmadan stop() çağırıla bilər — problem deyil.
            }
            it.release()
        }
        audioPlayer = null
        audioPrepared = false
        audioCompleted = false
    }

    override fun onDestroy() {
        releaseAudio()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BUILD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPlayBuild" -> {
                        val appInfo = packageManager.getApplicationInfo(
                            packageName, android.content.pm.PackageManager.GET_META_DATA
                        )
                        result.success(appInfo.metaData?.getBoolean(META_IS_PLAY_BUILD, false) ?: false)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // `source`: HTTP URL (axınla) və ya yerli fayl yolu (offline).
                    "play" -> {
                        val source = call.argument<String>("source")
                        if (source.isNullOrBlank()) {
                            result.error("no_source", "source verilməyib", null)
                            return@setMethodCallHandler
                        }
                        releaseAudio()
                        audioError = null
                        try {
                            val mp = MediaPlayer()
                            mp.setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .setUsage(AudioAttributes.USAGE_MEDIA)
                                    .build()
                            )
                            mp.setDataSource(source)
                            mp.setOnPreparedListener {
                                audioPrepared = true
                                it.start()
                            }
                            mp.setOnCompletionListener { audioCompleted = true }
                            mp.setOnErrorListener { _, what, extra ->
                                // Səssiz uğursuzluq OLMAMALIDIR — Dart tərəf
                                // bunu state() ilə oxuyub istifadəçiyə göstərir.
                                audioError = "MediaPlayer xətası ($what/$extra)"
                                true
                            }
                            // Şəbəkə mənbəyi üçün prepare() UI-ı dondurardı.
                            mp.prepareAsync()
                            audioPlayer = mp
                            result.success(true)
                        } catch (e: Exception) {
                            audioError = e.message ?: "açılmadı"
                            result.error("play_failed", audioError, null)
                        }
                    }
                    "pause" -> {
                        if (audioPrepared) audioPlayer?.pause()
                        result.success(true)
                    }
                    "resume" -> {
                        if (audioPrepared) {
                            audioCompleted = false
                            audioPlayer?.start()
                        }
                        result.success(true)
                    }
                    "seek" -> {
                        val ms = call.argument<Int>("ms") ?: 0
                        if (audioPrepared) {
                            audioCompleted = false
                            audioPlayer?.seekTo(ms)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        releaseAudio()
                        result.success(true)
                    }
                    "state" -> {
                        val mp = audioPlayer
                        result.success(
                            mapOf(
                                "prepared" to audioPrepared,
                                "playing" to (audioPrepared && mp?.isPlaying == true),
                                "completed" to audioCompleted,
                                "positionMs" to if (audioPrepared) (mp?.currentPosition ?: 0) else 0,
                                "durationMs" to if (audioPrepared) (mp?.duration ?: 0) else 0,
                                "error" to audioError
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
