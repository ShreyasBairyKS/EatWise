package com.example.eatwise

import android.content.Context
import android.provider.Settings
import android.text.TextUtils
import android.content.Intent
import android.net.Uri

/**
 * Utility class for checking and managing permissions
 */
object PermissionUtil {

    /**
     * Check if our Accessibility Service is enabled
     */
    fun isAccessibilityEnabled(context: Context): Boolean {
        val serviceName = "${context.packageName}/${IngredientAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return !TextUtils.isEmpty(enabledServices) && enabledServices.contains(serviceName)
    }

    /**
     * Open Android Accessibility Settings
     */
    fun openAccessibilitySettings(context: Context) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    /**
     * Check if overlay permission is granted
     */
    fun canDrawOverlays(context: Context): Boolean {
        return Settings.canDrawOverlays(context)
    }

    /**
     * Open overlay permission settings
     */
    fun openOverlaySettings(context: Context) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        )
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}
