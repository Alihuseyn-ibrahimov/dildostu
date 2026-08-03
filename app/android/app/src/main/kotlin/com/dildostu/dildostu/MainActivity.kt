package com.dildostu.dildostu

import android.content.Context
import android.content.Intent
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

class MainActivity : FlutterActivity() {
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
