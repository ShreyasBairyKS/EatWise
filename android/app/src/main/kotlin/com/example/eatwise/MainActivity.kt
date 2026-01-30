package com.example.eatwise

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.eatwise/methods"
        private const val EVENT_CHANNEL = "com.eatwise/events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel for commands from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> {
                        IngredientScanner.start(this)
                        result.success(true)
                    }
                    "stopScan" -> {
                        IngredientScanner.stop()
                        result.success(true)
                    }
                    "checkAccessibilityPermission" -> {
                        result.success(PermissionUtil.isAccessibilityEnabled(this))
                    }
                    "checkOverlayPermission" -> {
                        result.success(PermissionUtil.canDrawOverlays(this))
                    }
                    "openAccessibilitySettings" -> {
                        PermissionUtil.openAccessibilitySettings(this)
                        result.success(true)
                    }
                    "openOverlaySettings" -> {
                        PermissionUtil.openOverlaySettings(this)
                        result.success(true)
                    }
                    "showOverlay" -> {
                        OverlayService.start(this)
                        result.success(true)
                    }
                    "hideOverlay" -> {
                        OverlayService.stop(this)
                        result.success(true)
                    }
                    "isServiceReady" -> {
                        result.success(IngredientAccessibilityService.instance != null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event Channel for streaming data to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    IngredientScanner.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    IngredientScanner.eventSink = null
                }
            })
    }
    
    override fun onDestroy() {
        // Stop all background services when app is closed
        OverlayService.stop(this)
        IngredientScanner.stop()
        IngredientScanner.eventSink = null
        super.onDestroy()
    }
}
