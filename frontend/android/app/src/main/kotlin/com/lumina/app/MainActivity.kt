package com.lumina.app

import android.app.UiModeManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lumina's own dark mode setting, so Android's start-up screen (values-night) matches it on
        // the next launch instead of the phone's setting. Android 12+ only; older phones keep
        // following the phone's setting.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumina/night_mode")
            .setMethodCallHandler { call, result ->
                if (call.method != "set" || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val dark = call.arguments as? Boolean ?: false
                getSystemService(UiModeManager::class.java).setApplicationNightMode(
                    if (dark) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO,
                )
                result.success(true)
            }
    }
}
