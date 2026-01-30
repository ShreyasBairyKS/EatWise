package com.example.eatwise

import android.content.Context
import io.flutter.plugin.common.EventChannel

/**
 * Controller for ingredient scanning operations
 * Bridges the Accessibility Service with Flutter
 */
object IngredientScanner {
    
    var eventSink: EventChannel.EventSink? = null
    
    /**
     * Start scanning for ingredients
     */
    fun start(context: Context) {
        IngredientAccessibilityService.isScanning = true
        
        // Trigger immediate scan if service is connected
        IngredientAccessibilityService.instance?.processScreen()
    }
    
    /**
     * Stop scanning
     */
    fun stop() {
        IngredientAccessibilityService.isScanning = false
    }
    
    /**
     * Send ingredient text to Flutter
     */
    fun sendToFlutter(ingredientText: String) {
        val data = mapOf(
            "type" to "ingredientText",
            "data" to ingredientText,
            "timestamp" to System.currentTimeMillis()
        )
        eventSink?.success(data)
    }
    
    /**
     * Send error to Flutter
     */
    fun sendError(code: String, message: String) {
        eventSink?.error(code, message, null)
    }
    
    /**
     * Send status update to Flutter
     */
    fun sendStatus(status: String) {
        val data = mapOf(
            "type" to "status",
            "data" to status,
            "timestamp" to System.currentTimeMillis()
        )
        eventSink?.success(data)
    }
}
