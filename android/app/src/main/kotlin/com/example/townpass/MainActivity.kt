package com.example.townpass

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.townpass/google_maps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setApiKey") {
                // 在 Android 上，API Key 已經通過 AndroidManifest.xml 配置
                // 這裡只需要返回成功即可
                val apiKey = call.arguments as? String
                if (apiKey != null && apiKey.isNotEmpty()) {
                    // API Key 已通過 AndroidManifest.xml 設定，這裡只做確認
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "API Key is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
