# 🍎 EatWise - Implementation Guide

## Background Ingredient Intelligence Chatbot

> A Flutter + Kotlin Android app that uses an Accessibility Service to analyze food ingredients in real-time from shopping apps like Swiggy, Blinkit, and Zepto.

> **Note:** This guide mirrors the actual code in `lib/` and `android/app/src/main/` as of the `com.eatwise.app` package rename. Treat those directories as the source of truth if they've since diverged from what's shown here. Sections describing features that were planned but never built are marked **Not implemented**.

---

## 📋 Table of Contents

1. [Project Setup](#1-project-setup)
2. [Android Configuration](#2-android-configuration)
3. [Accessibility Service Implementation](#3-accessibility-service-implementation)
4. [Flutter-Kotlin Bridge (MethodChannel)](#4-flutter-kotlin-bridge-methodchannel)
5. [Floating Overlay UI](#5-floating-overlay-ui)
6. [OCR Fallback with ML Kit](#6-ocr-fallback-with-ml-kit)
7. [Ingredient Processing Engine](#7-ingredient-processing-engine)
8. [AI Backend Integration](#8-ai-backend-integration)
9. [Chatbot UI Implementation](#9-chatbot-ui-implementation)
10. [Privacy & Permissions](#10-privacy--permissions)
11. [Testing & Debugging](#11-testing--debugging)
12. [Deployment Checklist](#12-deployment-checklist)

---

## 1. Project Setup

### 1.1 Create Flutter Project

```bash
flutter create eatwise --platforms=android
cd eatwise
```

### 1.2 Project Structure

```
eatwise/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── platform_channel.dart      # Native bridge (NativeBridge)
│   │   ├── constants.dart             # AppConstants, IngredientKeywords
│   │   ├── knowledge_base.dart        # Local ingredient database
│   │   ├── api_config.dart            # gitignored - real API key, not committed
│   │   └── api_config.template.dart   # Copy to api_config.dart and fill in a key
│   ├── features/
│   │   ├── chatbot/
│   │   │   ├── home_screen.dart       # Permission setup + start screen
│   │   │   ├── chat_screen.dart       # Main chat UI
│   │   │   └── chatbot_controller.dart
│   │   └── scanner/
│   │       └── ingredient_parser.dart
│   └── services/
│       └── ai_service.dart
├── android/
│   └── app/src/main/
│       ├── kotlin/com/eatwise/app/
│       │   ├── MainActivity.kt
│       │   ├── IngredientScanner.kt
│       │   ├── IngredientAccessibilityService.kt
│       │   ├── OverlayService.kt
│       │   └── PermissionUtil.kt
│       └── res/xml/
│           └── accessibility_service_config.xml
```

There is currently no `test/` directory - see [Section 11](#11-testing--debugging).

### 1.3 Add Dependencies

**pubspec.yaml** (actual, current)
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  provider: ^6.1.2

  # HTTP Client
  http: ^1.2.1

  # Local Storage
  shared_preferences: ^2.2.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  flutter_launcher_icons: ^0.14.3
```

`shared_preferences` is declared but not yet read/written anywhere - see [Section 10.2](#102-consent-dialog--onboarding). `google_mlkit_text_recognition` was removed since nothing used it - see [Section 6](#6-ocr-fallback-with-ml-kit).

Run:
```bash
flutter pub get
```

---

## 2. Android Configuration

### 2.1 `android/app/build.gradle.kts` (actual, current)

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eatwise.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.eatwise.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            // TODO: add a real release signing config before shipping to Play Store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
```

`buildFeatures.buildConfig = true` is required because newer Android Gradle Plugin versions no longer generate the `BuildConfig` class by default. Without it, `BuildConfig.DEBUG` (used to gate sensitive logging - see [Section 3.2](#32-create-accessibility-service)) fails to compile.

### 2.2 `AndroidManifest.xml` (actual, current)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:label="EatWise"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Accessibility Service for reading screen content -->
        <service
            android:name=".IngredientAccessibilityService"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
            android:exported="false">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config" />
        </service>

        <!-- Foreground Service for Overlay -->
        <service
            android:name=".OverlayService"
            android:foregroundServiceType="specialUse"
            android:exported="false">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="Display floating overlay for ingredient scanning" />
        </service>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

### 2.3 Accessibility Config (actual, current)

**`android/app/src/main/res/xml/accessibility_service_config.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_description"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:canRetrieveWindowContent="true"
    android:canPerformGestures="false"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows|flagIncludeNotImportantViews|flagRequestEnhancedWebAccessibility"
    android:notificationTimeout="100"
    android:settingsActivity="com.eatwise.app.MainActivity" />
```

### 2.4 String Resources (actual, current)

**`android/app/src/main/res/values/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">EatWise</string>
    <string name="accessibility_description">EatWise reads on-screen text only to analyze food ingredients and provide health insights. No data is stored without your consent. Your privacy is protected.</string>
</resources>
```

---

## 3. Accessibility Service Implementation

### 3.1 Permission Utility (actual, current)

**`android/app/src/main/kotlin/com/eatwise/app/PermissionUtil.kt`**

```kotlin
package com.eatwise.app

import android.content.Context
import android.provider.Settings
import android.text.TextUtils
import android.content.Intent
import android.net.Uri

object PermissionUtil {

    fun isAccessibilityEnabled(context: Context): Boolean {
        val serviceName = "${context.packageName}/${IngredientAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return !TextUtils.isEmpty(enabledServices) && enabledServices.contains(serviceName)
    }

    fun openAccessibilitySettings(context: Context) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    fun canDrawOverlays(context: Context): Boolean {
        return Settings.canDrawOverlays(context)
    }

    fun openOverlaySettings(context: Context) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        )
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}
```

### 3.2 Create Accessibility Service

**`android/app/src/main/kotlin/com/eatwise/app/IngredientAccessibilityService.kt`**

The core behavior: on a triggered scan, walk every accessibility node in every open window (not just the active one - overlays/dialogs matter too), collect their text/content-description/hint/tooltip strings, then look for an ingredients anchor (`"ingredients:"`, `"contains"`, Hindi variants, etc. - see `ingredientAnchors` below, kept in sync by hand with `IngredientKeywords` in `lib/core/constants.dart`).

**Privacy-critical rule: if no anchor is found, nothing is forwarded to Flutter at all.** The scan can be triggered while any app is in the foreground, so unrelated on-screen text (which could be anything - not just food labels) must never leave the accessibility service. An earlier version of this code fell back to sending the whole screen's text when no anchor matched; that was removed because it silently contradicted the in-app privacy notice, which claims "no data is shared."

```kotlin
package com.eatwise.app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class IngredientAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "EatWiseAccessibility"
        var instance: IngredientAccessibilityService? = null
        var isScanning = false
    }

    // Keyword anchors to detect ingredient sections.
    // Kept in sync by hand with IngredientKeywords in lib/core/constants.dart -
    // update both when changing either.
    private val ingredientAnchors = listOf(
        "ingredients:", "ingredients", "contains:", "contains",
        "composition:", "composition", "made with", "made from",
        "contents:", "contents", "ingredients list",
        // Hindi/Indian variants
        "सामग्री", "घटक"
    )

    // Stop words to end extraction
    private val stopKeywords = listOf(
        "allergen", "allergy", "allergy advice", "storage", "store in",
        "nutritional", "nutrition facts", "nutrition information",
        "directions", "best before", "expiry", "exp date",
        "manufactured", "packed by", "marketed by", "fssai",
        "net weight", "net wt", "net qty", "serving size",
        "how to use", "customer care", "disclaimer", "warning"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isScanning) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                processScreen()
            }
        }
    }

    fun processScreen() {
        val root = rootInActiveWindow ?: run {
            IngredientScanner.sendStatus("No screen content available. Make sure you're on a product page.")
            isScanning = false
            return
        }

        val collectedText = StringBuilder()

        try {
            windows?.forEach { window ->
                try {
                    window.root?.let { traverseNode(it, collectedText) }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing window: ${e.message}")
                }
            }
            traverseNode(root, collectedText)
        } catch (e: Exception) {
            Log.e(TAG, "Error during traversal: ${e.message}")
        }

        val fullText = collectedText.toString()
        // Scanned screen content can include anything visible in any app -
        // only ever log it in debug builds, never in a release build.
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "First 500 chars: ${fullText.take(500)}")
        }

        val ingredientBlock = extractIngredientBlock(fullText)

        if (ingredientBlock.isNotEmpty() && ingredientBlock.length > 20) {
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Found ingredients: ${ingredientBlock.take(200)}...")
            }
            IngredientScanner.sendToFlutter(ingredientBlock)
        } else {
            // No ingredients anchor found: do NOT forward arbitrary on-screen text.
            IngredientScanner.sendStatus("No ingredient list found. Scroll to show ingredients and try again.")
        }

        isScanning = false
        try { root.recycle() } catch (e: Exception) { /* Ignore recycle errors */ }
    }

    private fun traverseNode(node: AccessibilityNodeInfo?, builder: StringBuilder, depth: Int = 0) {
        if (node == null || depth > 50) return // Prevent infinite recursion

        node.text?.let { val s = it.toString().trim(); if (s.length > 1) builder.append(s).append(" ") }
        node.contentDescription?.let { val s = it.toString().trim(); if (s.length > 1) builder.append(s).append(" ") }
        node.hintText?.let { val s = it.toString().trim(); if (s.length > 1) builder.append(s).append(" ") }
        node.tooltipText?.let { val s = it.toString().trim(); if (s.length > 1) builder.append(s).append(" ") }

        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i)
                if (child != null) {
                    traverseNode(child, builder, depth + 1)
                    try { child.recycle() } catch (e: Exception) { /* Ignore */ }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error traversing child node: ${e.message}")
            }
        }
    }

    private fun extractIngredientBlock(text: String): String {
        val lowerText = text.lowercase()

        var startIndex = -1
        for (anchor in ingredientAnchors) {
            val idx = lowerText.indexOf(anchor)
            if (idx != -1) { startIndex = idx; break }
        }
        if (startIndex == -1) return ""

        var endIndex = text.length
        for (stop in stopKeywords) {
            val idx = lowerText.indexOf(stop, startIndex + 10)
            if (idx != -1 && idx < endIndex) endIndex = idx
        }
        endIndex = minOf(endIndex, startIndex + 2000)

        return text.substring(startIndex, endIndex).trim()
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        instance = null
        isScanning = false
        super.onDestroy()
    }
}
```

### 3.3 Ingredient Scanner Controller (actual, current)

**`android/app/src/main/kotlin/com/eatwise/app/IngredientScanner.kt`**

```kotlin
package com.eatwise.app

import android.content.Context
import io.flutter.plugin.common.EventChannel

object IngredientScanner {

    var eventSink: EventChannel.EventSink? = null

    fun start(context: Context) {
        IngredientAccessibilityService.isScanning = true
        IngredientAccessibilityService.instance?.processScreen()
    }

    fun stop() {
        IngredientAccessibilityService.isScanning = false
    }

    fun sendToFlutter(ingredientText: String) {
        eventSink?.success(mapOf(
            "type" to "ingredientText",
            "data" to ingredientText,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    fun sendError(code: String, message: String) {
        eventSink?.error(code, message, null)
    }

    fun sendStatus(status: String) {
        eventSink?.success(mapOf(
            "type" to "status",
            "data" to status,
            "timestamp" to System.currentTimeMillis()
        ))
    }
}
```

---

## 4. Flutter-Kotlin Bridge (MethodChannel)

### 4.1 MainActivity (actual, current)

**`android/app/src/main/kotlin/com/eatwise/app/MainActivity.kt`**

```kotlin
package com.eatwise.app

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> { IngredientScanner.start(this); result.success(true) }
                    "stopScan" -> { IngredientScanner.stop(); result.success(true) }
                    "checkAccessibilityPermission" -> result.success(PermissionUtil.isAccessibilityEnabled(this))
                    "checkOverlayPermission" -> result.success(PermissionUtil.canDrawOverlays(this))
                    "openAccessibilitySettings" -> { PermissionUtil.openAccessibilitySettings(this); result.success(true) }
                    "openOverlaySettings" -> { PermissionUtil.openOverlaySettings(this); result.success(true) }
                    "showOverlay" -> { OverlayService.start(this); result.success(true) }
                    "hideOverlay" -> { OverlayService.stop(this); result.success(true) }
                    "isServiceReady" -> result.success(IngredientAccessibilityService.instance != null)
                    else -> result.notImplemented()
                }
            }

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
```

### 4.2 Flutter Platform Channel (actual, current)

**`lib/core/platform_channel.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

class NativeBridge {
  static const MethodChannel _methodChannel =
      MethodChannel(AppConstants.methodChannel);
  static const EventChannel _eventChannel =
      EventChannel(AppConstants.eventChannel);

  static Future<bool> startScan() async {
    try {
      final result = await _methodChannel.invokeMethod('startScan');
      return result == true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error starting scan: $e');
      return false;
    }
  }

  static Future<bool> stopScan() async { /* ...same pattern... */ return false; }
  static Future<bool> checkAccessibilityPermission() async { /* ... */ return false; }
  static Future<bool> checkOverlayPermission() async { /* ... */ return false; }
  static Future<void> openAccessibilitySettings() async { /* ... */ }
  static Future<void> openOverlaySettings() async { /* ... */ }
  static Future<bool> showOverlay() async { /* ... */ return false; }
  static Future<bool> hideOverlay() async { /* ... */ return false; }
  static Future<bool> isServiceReady() async { /* ... */ return false; }

  static Stream<Map<String, dynamic>>? _ingredientStreamInstance;

  /// Singleton broadcast stream so multiple widgets can listen without
  /// each attaching a separate native listener.
  static Stream<Map<String, dynamic>> ingredientStream() {
    _ingredientStreamInstance ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event is Map
            ? Map<String, dynamic>.from(event)
            : <String, dynamic>{'type': 'unknown', 'data': event})
        .asBroadcastStream();
    return _ingredientStreamInstance!;
  }
}
```

Every method wraps its channel call in try/catch and falls back to a safe default (`false`/void) on error - see the full file for each method body. Errors log via `debugPrint` gated on `kDebugMode`, so nothing prints in a release build.

---

## 5. Floating Overlay UI

### 5.1 Overlay Service (actual, current)

**`android/app/src/main/kotlin/com/eatwise/app/OverlayService.kt`**

Key differences from a minimal version: the floating button uses the app's launcher icon inside a white circle with a green border (falls back to a search icon if that fails), the notification opens `MainActivity` when tapped, and the touch listener distinguishes a drag from a tap using both movement distance and touch duration (a tap under 300ms that moved less than 10px triggers a scan, with a small pulse animation for feedback).

```kotlin
package com.eatwise.app

import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import android.graphics.drawable.GradientDrawable

class OverlayService : Service() {

    companion object {
        private const val CHANNEL_ID = "eatwise_overlay_channel"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }
    }

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        showOverlay()
    }

    // ...createNotificationChannel(), createNotification() build a low-priority,
    // ongoing notification that opens MainActivity when tapped...

    private fun showOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 50; y = 400 }

        overlayView = createFloatingButton()
        setupTouchListener(overlayView!!, params)
        windowManager.addView(overlayView, params)
    }

    // createFloatingButton(): ImageView with the launcher icon, white circular
    // background, green stroke border, and elevation for a shadow.

    // setupTouchListener(): ACTION_DOWN records start position/time;
    // ACTION_MOVE drags the view and flips isClick=false past a 10px threshold;
    // ACTION_UP triggers IngredientScanner.start(this) + a pulse animation
    // when isClick is still true and the touch lasted under 300ms.

    override fun onDestroy() {
        overlayView?.let { try { windowManager.removeView(it) } catch (e: Exception) {} }
        overlayView = null
        super.onDestroy()
    }
}
```

See the actual file for the full notification-channel and touch-listener bodies.

---

## 6. OCR Fallback with ML Kit

**Not implemented, and the dependency was removed.** `google_mlkit_text_recognition` used to sit in `pubspec.yaml` with no `OCRService.kt` and no `lib/services/ocr_service.dart` behind it anywhere in the codebase - ingredient detection relies entirely on the Accessibility Service reading text nodes (Section 3), not on image OCR. Since nothing used it, the dependency (and its ML Kit ProGuard rules - Section 12.5) were dropped rather than left declared and dead. If OCR is picked back up as a fallback (e.g. for screens that render ingredient text as an image rather than real text nodes), re-add `google_mlkit_text_recognition` and wire it up properly at that point.

---

## 7. Ingredient Processing Engine

### 7.1 Ingredient Parser (actual, current)

**`lib/features/scanner/ingredient_parser.dart`**

Unlike a naive comma-split, the real parser: (1) locates the ingredients block using the same anchor/stop-word lists as the Kotlin side (`IngredientKeywords` in `constants.dart`), (2) flattens parenthetical sub-ingredients into the flat list, (3) strips bracketed content and percentages, (4) tags E-number/INS additive codes, and (5) exposes a `quickExtract()` fallback for comma-separated lists that don't match a recognized anchor pattern.

```dart
import '../../core/constants.dart';

class IngredientParser {
  static final RegExp _additivePattern =
      RegExp(r'(E\d{3,4}[a-z]?|INS\s?\d{3,4})', caseSensitive: false);
  static final RegExp _separatorPattern = RegExp(r'[,;|•·]');
  static final RegExp _percentagePattern = RegExp(r'\d+\.?\d*\s*%');

  static List<Ingredient> parse(String rawText) {
    final ingredientBlock = _extractIngredientBlock(rawText);
    if (ingredientBlock.isEmpty) return [];

    String cleaned = ingredientBlock
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    cleaned = _flattenParentheses(cleaned);

    final parts = cleaned.split(_separatorPattern);
    final ingredients = <Ingredient>[];
    for (var part in parts) {
      var name = part.trim();
      if (name.isEmpty || name.length < 2) continue;
      if (RegExp(r'^\d+\.?\d*%?$').hasMatch(name)) continue;

      String? percentage;
      final percentMatch = _percentagePattern.firstMatch(name);
      if (percentMatch != null) {
        percentage = percentMatch.group(0);
        name = name.replaceAll(_percentagePattern, '').trim();
      }

      final isAdditive = _additivePattern.hasMatch(name);
      final additiveCode = _extractAdditiveCode(name);
      name = _normalizeIngredientName(name);

      if (name.isNotEmpty && name.length >= 2) {
        ingredients.add(Ingredient(
          name: name, isAdditive: isAdditive,
          additiveCode: additiveCode, percentage: percentage,
        ));
      }
    }
    return ingredients;
  }

  static String _extractIngredientBlock(String text) {
    final lowerText = text.toLowerCase();
    int startIndex = -1;
    for (final anchor in IngredientKeywords.anchors) {
      final idx = lowerText.indexOf(anchor);
      if (idx != -1) { startIndex = idx + anchor.length; break; }
    }
    if (startIndex == -1) return ''; // No anchor - don't process random text

    int endIndex = text.length;
    for (final stop in IngredientKeywords.stopWords) {
      final idx = lowerText.indexOf(stop, startIndex + 5);
      if (idx != -1 && idx < endIndex) endIndex = idx;
    }
    return text.substring(startIndex, endIndex).trim();
  }

  static String _flattenParentheses(String text) => text
      .replaceAll('(', ', ').replaceAll(')', '')
      .replaceAll(RegExp(r',\s*,'), ',');

  static String _normalizeIngredientName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'^\d+\.?\s*'), '')
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String? _extractAdditiveCode(String name) =>
      _additivePattern.firstMatch(name)?.group(0)?.toUpperCase();

  /// Fallback: split the anchored block on separators without full parsing.
  static List<String> quickExtract(String text) {
    final block = _extractIngredientBlock(text);
    return block.split(_separatorPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length >= 2)
        .toList();
  }
}

class Ingredient {
  final String name;
  final bool isAdditive;
  final String? additiveCode;
  final String? percentage;

  Ingredient({required this.name, required this.isAdditive, this.additiveCode, this.percentage});

  Map<String, dynamic> toJson() =>
      {'name': name, 'isAdditive': isAdditive, 'additiveCode': additiveCode, 'percentage': percentage};
}
```

### 7.2 Local Knowledge Base (actual, current)

**`lib/core/knowledge_base.dart`**

Uses a `HealthImpact` enum (`positive`/`neutral`/`caution`/`negative`) rather than raw strings, and each entry supports emoji/text getters for display:

```dart
class IngredientKnowledgeBase {
  static final Map<String, IngredientInfo> _database = {
    'sugar': IngredientInfo(
      category: 'Sweetener',
      healthImpact: HealthImpact.negative,
      concerns: ['Blood sugar spike', 'Weight gain', 'Dental issues'],
      dailyLimit: '25g (WHO recommendation)',
    ),
    'stevia': IngredientInfo(
      category: 'Natural Sweetener',
      healthImpact: HealthImpact.positive,
      benefits: ['Zero calories', 'Natural origin', "Doesn't spike blood sugar"],
    ),
    'e621': IngredientInfo(
      category: 'Flavor Enhancer',
      healthImpact: HealthImpact.caution,
      commonName: 'MSG',
      concerns: ['May cause headaches in sensitive individuals'],
    ),
    // ...~20 entries total covering sweeteners, fats, preservatives,
    // flavor enhancers, colors, common E-numbers, and healthy grains.
  };

  static IngredientInfo? lookup(String ingredientName) {
    final normalized = ingredientName.toLowerCase().trim();
    if (_database.containsKey(normalized)) return _database[normalized];
    for (final entry in _database.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }
    return null;
  }
}

enum HealthImpact { positive, neutral, caution, negative }

class IngredientInfo {
  final String category;
  final HealthImpact healthImpact;
  final String? commonName;
  final List<String> concerns;
  final List<String>? benefits;
  final String? dailyLimit;
  final List<String>? alternatives;
  // ...healthImpactEmoji / healthImpactText getters for display
}
```

See `lib/core/knowledge_base.dart` for the full ~20-entry database.

---

## 8. AI Backend Integration

### 8.1 AI Service (actual, current)

**`lib/services/ai_service.dart`**

The real service is considerably more robust than a bare API call: it supports either OpenRouter or direct OpenAI (`AppConstants.useOpenRouter`), falls back to a substantial **local, offline analysis** (keyword-matched concerns/benefits/allergens plus the knowledge base) whenever the API key isn't configured, the call fails, or the response can't be parsed, and folds in the user's allergies/diet/health conditions when present.

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/knowledge_base.dart';

class AIService {
  static Future<HealthAnalysis> analyzeIngredients(
    List<String> ingredients, {
    UserHealthProfile? userProfile,
  }) async {
    if (ingredients.isEmpty) {
      return HealthAnalysis(
        summary: 'No ingredients were provided for analysis.',
        concerns: [], benefits: [], overallRating: 1,
        recommendations: ['Please provide a list of ingredients for analysis.'],
        allergens: [],
      );
    }

    if (AppConstants.apiKey == 'YOUR_API_KEY_HERE' ||
        AppConstants.apiKey.isEmpty ||
        AppConstants.apiKey.contains('\n')) {
      return _localAnalysis(ingredients, userProfile);
    }

    try {
      final prompt = _buildPrompt(ingredients, userProfile);
      final baseUrl = AppConstants.useOpenRouter ? AppConstants.openRouterBaseUrl : AppConstants.openAiBaseUrl;
      final model = AppConstants.useOpenRouter ? AppConstants.openRouterModel : AppConstants.openAiModel;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.apiKey.trim()}',
      };
      if (AppConstants.useOpenRouter) {
        headers['HTTP-Referer'] = 'https://eatwise.app';
        headers['X-Title'] = 'EatWise Ingredient Analyzer';
      }

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': '...analyst system prompt requesting strict JSON...'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 600,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var jsonStr = data['choices'][0]['message']['content'].toString().trim();
        if (jsonStr.contains('```')) {
          jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
        }
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
        if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;
        return HealthAnalysis.fromJson(jsonDecode(jsonStr));
      }
      return _localAnalysis(ingredients, userProfile);
    } catch (e, stackTrace) {
      if (kDebugMode) { debugPrint('AI Analysis Error: $e'); debugPrint('Stack trace: $stackTrace'); }
      return _localAnalysis(ingredients, userProfile);
    }
  }

  // _localAnalysis(): keyword-matches ~35 "bad" ingredients, ~25 "good"
  // ingredients, and ~25 allergen triggers, cross-checks the knowledge
  // base, scores 1-10, and flags the user's own declared allergens first.
}
```

See `lib/services/ai_service.dart` for the full system prompt, `_localAnalysis()` keyword tables, and the `HealthAnalysis`/`UserHealthProfile` model classes (which include `allergens` - not present in earlier drafts of this service).

### 8.2 Web Search Fallback

**Not implemented.** There is no `WebSearchService` or SerpAPI integration in the current codebase; ingredient analysis relies solely on [Section 8.1](#81-ai-service-actual-current)'s AI call and its local fallback.

---

## 9. Chatbot UI Implementation

### 9.1 Main App Entry (actual, current)

**`lib/main.dart`**

Unlike a bare `MaterialApp`, the real entry point is a `StatefulWidget` with a `WidgetsBindingObserver` so the overlay and accessibility scan are stopped when the app is backgrounded/terminated (`AppLifecycleState.detached`) or disposed - otherwise the floating button and scan state could outlive the Flutter engine.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/chatbot/chatbot_controller.dart';
import 'features/chatbot/home_screen.dart';
import 'core/platform_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EatWiseApp());
}

class EatWiseApp extends StatefulWidget {
  const EatWiseApp({super.key});
  @override
  State<EatWiseApp> createState() => _EatWiseAppState();
}

class _EatWiseAppState extends State<EatWiseApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAllServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _stopAllServices();
  }

  Future<void> _stopAllServices() async {
    try {
      await NativeBridge.hideOverlay();
      await NativeBridge.stopScan();
    } catch (e) { /* Ignore errors during cleanup */ }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatbotController(),
      child: MaterialApp(
        title: 'EatWise',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
```

### 9.2 Home Screen (actual, current)

**`lib/features/chatbot/home_screen.dart`**

Rechecks permissions whenever the app resumes (in case the user changed them in Settings and came back), and the privacy notice text is:

> "We only read text when you tap scan, and only send it for analysis when it looks like an ingredient list. Nothing is stored."

(An earlier version of this notice claimed "No data is stored or shared" - inaccurate, since matched ingredient text *is* sent to a third-party AI API for analysis. See `_buildPrivacyNotice()` in the actual file.)

Before any of that renders, `initState` awaits `ConsentDialog.show(context)` (Section 10.2) and gates the whole screen on the result: while it's resolving, a spinner shows; if declined, `_buildConsentRequired()` renders instead of the permission UI; only once consented does the rest of the screen - hero section with the app logo (falls back to an icon if the asset fails to load), two permission cards (Accessibility, Display over apps) each showing an Enable button or an Enabled badge, and a Start button disabled until both permissions are granted - appear.

### 9.3 Chat Screen (actual, current)

**`lib/features/chatbot/chat_screen.dart`**

Beyond a bare message list, the real screen: shows a welcome message with usage instructions on first open, reconnects the ingredient stream on app resume, shows a scanning indicator while `controller.isScanning` is true, supports a manual scan button plus pasting text directly into the input field (auto-detected as an ingredient list vs. a plain question by the presence of commas or words like "ingredients"/"contains"), and a "Clear Chat" action with a confirmation dialog.

```dart
class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  // ...
  void _startListening() {
    _ingredientSubscription = NativeBridge.ingredientStream().listen((event) {
      if (event['type'] == 'ingredientText') {
        final data = event['data'] as String?;
        if (data != null && data.isNotEmpty) {
          // isUserProvided defaults to false - this is scanned content, not
          // something the user typed, so the AI fallback path stays restricted.
          context.read<ChatbotController>().processIngredients(data);
        }
      } else if (event['type'] == 'status') {
        // show a SnackBar with the status message
      }
    });
  }

  void _sendMessage(ChatbotController controller) {
    final text = _messageController.text.trim();
    final looksLikeIngredients = text.contains(',') ||
        text.toLowerCase().contains('ingredients') ||
        text.toLowerCase().contains('contains') ||
        text.split(RegExp(r'[,;]')).length > 2;

    if (looksLikeIngredients) {
      // User typed/pasted this directly - safe to use the AI fallback path.
      controller.processIngredients(text, isUserProvided: true);
    } else {
      controller.sendMessage(text);
    }
  }
}
```

### 9.4 Chatbot Controller (actual, current)

**`lib/features/chatbot/chatbot_controller.dart`**

The `isUserProvided` flag on `processIngredients()` is the privacy boundary described in Section 3.2: scanned text only reaches the AI service once `IngredientParser` has matched a real anchor; the "just send whatever raw words we found" fallback only runs for text the user explicitly typed or pasted.

```dart
class ChatbotController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isScanning = false;
  UserHealthProfile? _userProfile;

  Future<void> processIngredients(String rawText, {bool isUserProvided = false}) async {
    if (rawText.trim().length < 10) return;
    _isLoading = true;
    notifyListeners();

    try {
      final ingredients = IngredientParser.parse(rawText);

      if (ingredients.isEmpty) {
        final quickList = IngredientParser.quickExtract(rawText);
        if (quickList.length >= 2) {
          final filtered = quickList.where((s) => s.length > 2 && !RegExp(r'^\d+$').hasMatch(s)).toList();
          if (filtered.isNotEmpty) {
            final analysis = await AIService.analyzeIngredients(filtered, userProfile: _userProfile);
            addMessage(ChatMessage(text: _buildSimpleAnalysisResponse(analysis, filtered), isUser: false, type: MessageType.analysis, analysis: analysis));
            _isLoading = false; notifyListeners();
            return;
          }
        }

        // Only for text the user explicitly typed/pasted - never for scanned
        // content that didn't match an anchor.
        if (isUserProvided && rawText.length > 100) {
          final words = rawText.replaceAll(RegExp(r'[^\w\s,]'), ' ')
              .split(RegExp(r'[\s,]+')).where((w) => w.length > 2).take(30).toList();
          if (words.isNotEmpty) {
            final analysis = await AIService.analyzeIngredients(words, userProfile: _userProfile);
            addMessage(ChatMessage(text: _buildSimpleAnalysisResponse(analysis, words), isUser: false, type: MessageType.analysis, analysis: analysis));
            _isLoading = false; notifyListeners();
            return;
          }
        }

        addMessage(ChatMessage(text: '🔍 No ingredients detected.\n\nTips:\n...', isUser: false, type: MessageType.info));
        _isLoading = false; notifyListeners();
        return;
      }

      final analysis = await AIService.analyzeIngredients(
        ingredients.map((i) => i.name).toList(), userProfile: _userProfile,
      );
      addMessage(ChatMessage(text: _buildAnalysisResponse(analysis, ingredients), isUser: false, type: MessageType.analysis, analysis: analysis));
    } catch (e) {
      addMessage(ChatMessage(text: '❌ Analysis failed: $e', isUser: false, type: MessageType.error));
    }

    _isLoading = false;
    notifyListeners();
  }

  // sendMessage()/_generateResponse(): a small canned FAQ (how-to-use,
  // sugar, MSG, preservatives) for plain chat questions that aren't
  // ingredient lists.
}
```

See the actual file for `_buildAnalysisResponse()`/`_buildSimpleAnalysisResponse()` (health score, allergens, concerns, benefits, additive codes, recommendations, and an "educational info only" disclaimer) and the `ChatMessage`/`MessageType` model.

---

## 10. Privacy & Permissions

### 10.1 Privacy Policy Requirements

Still relevant, unchanged:

1. **Data Collection**: Only ingredient text when the user initiates a scan, and only once it matches a recognized ingredients anchor (see [Section 3.2](#32-create-accessibility-service)).
2. **Data Storage**: No screenshots or screen data stored on-device or off.
3. **Data Transmission**: Matched ingredient text (or user-typed text) is sent to the configured AI backend (OpenRouter/OpenAI) over HTTPS for analysis.
4. **Third-Party Sharing**: Ingredient text (and, if set, the user's allergy/diet/health-condition profile) goes to the AI provider as part of the analysis request - this should be disclosed plainly, not glossed over.
5. **User Control**: Accessibility/overlay permissions can be revoked anytime in Android Settings; the app also has a manual "stop scanning" path.

### 10.2 Consent Dialog / Onboarding (actual, current)

**`lib/features/onboarding/consent_dialog.dart`**

Shown once via `HomeScreen` (in `initState`, after the first frame) before the permission-setup UI is ever displayed. `ConsentDialog.show(context)` checks `AppConstants.prefUserConsented` in `SharedPreferences`; if already `true` it returns immediately without showing anything. Otherwise it shows a non-dismissible dialog describing exactly what the Accessibility/Overlay permissions are used for and what is/isn't sent off-device (matching the actual behavior in Section 3.2 and 8.1 - it explicitly says matched ingredient text goes to the AI service, unlike an earlier draft of this dialog that claimed nothing was shared).

- **Agree** persists `prefUserConsented = true` and the home screen proceeds to the normal permission cards.
- **Decline** does not persist anything, and the home screen shows a locked-out state (hero + a short explanation + a "Review Privacy Notice" button that re-triggers the dialog) instead of the permission UI - the app can't function without those permissions anyway, so there's no reason to let the user past without agreeing.

`prefOnboardingComplete` is still unused - there's no multi-step onboarding flow, only this single consent gate. Verified on-device (Pixel 8 Pro emulator): fresh install shows the dialog, Decline locks the screen with a working retry, Agree proceeds to permissions, and a full app restart after agreeing does not re-show the dialog.

---

## 11. Testing & Debugging

### 11.1 Inspect the Accessibility Service

```bash
# Check if service is running
adb shell dumpsys accessibility | grep -i eatwise

# View accessibility logs (structural logs only in a release build -
# scanned content itself is gated behind BuildConfig.DEBUG, see Section 3.2)
adb logcat | grep -i "EatWiseAccessibility"
```

### 11.2 Automated Tests

**Not implemented.** There is currently no `test/` directory (`flutter test` reports "Test directory not found"). Reasonable first targets if a suite gets added: `IngredientParser.parse()`/`quickExtract()` against representative label text, `AIService._localAnalysis()`'s scoring/keyword-matching, and `IngredientKnowledgeBase.lookup()`.

### 11.3 Debug Checklist

- [ ] Accessibility service appears in Android settings
- [ ] Service activates when enabled
- [ ] Floating icon appears and is draggable
- [ ] Tap on icon triggers scan
- [ ] Text extraction works on Swiggy/Blinkit
- [ ] Ingredients parsed correctly
- [ ] AI analysis returns a valid response, and falls back to local analysis when the API key is missing/invalid
- [ ] Chat UI updates properly
- [ ] `flutter analyze` reports no issues

---

## 12. Deployment Checklist

### 12.1 Release Signing Setup (actual, current)

`buildTypes.release` in `android/app/build.gradle.kts` uses a real keystore once `android/key.properties` exists, and falls back to the debug keystore when it doesn't - so `flutter run --release` keeps working locally before signing is set up, but **a debug-signed build must never ship to Play Store**.

To set up real signing:

1. Generate a keystore yourself (run this in your own terminal - it prompts for a keystore password, a key password, and certificate details; choose your own values, don't reuse examples, and don't ask an AI assistant to generate or store them for you):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Move the resulting `upload-keystore.jks` into `android/app/` (or wherever you reference it from in step 2).
2. Copy `android/key.properties.template` to `android/key.properties` (already gitignored via `android/.gitignore`, alongside `**/*.jks`/`**/*.keystore`) and fill in the real values:
   ```properties
   storePassword=<your keystore password>
   keyPassword=<your key password>
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
3. Build - `flutter build apk --release` (or `appbundle`) now signs with that keystore automatically; `build.gradle.kts` reads `key.properties` and wires `signingConfigs.release` accordingly, with no other changes needed.

**Back up the keystore and its passwords somewhere durable and separate from this repo.** Losing them means you can never publish an update to the same Play Store listing again - Google cannot reissue a lost upload key.

### 12.2 Pre-Release

- [x] Debug logging is gated behind `kDebugMode` (Dart) / `BuildConfig.DEBUG` (Kotlin) rather than needing manual removal - verify no new `print()`/unconditional `Log.d(...)` calls carrying scanned content have crept back in.
- [x] `applicationId`/`namespace` set to a real value (`com.eatwise.app`), not the `com.example.eatwise` template default.
- [ ] Generate a real release keystore and `android/key.properties` (Section 12.1) - the build already supports it, but no keystore has been generated yet, so release builds still fall back to debug signing.
- [x] `isMinifyEnabled`/`isShrinkResources` enabled; the ML Kit ProGuard rules were removed along with the unused dependency (see 12.5 and Section 6) - re-add them only if OCR is reintroduced.
- [ ] Test on multiple devices/Android versions, especially permission flows on OEM skins known to restrict Accessibility Services (e.g. MIUI, One UI).
- [x] Consent flow implemented (Section 10.2) - a first-launch dialog gates the permission-setup screen; declining locks the user out with a retry rather than proceeding.

### 12.3 Play Store Requirements

1. **Accessibility Service Declaration**
   - Must justify why accessibility is needed
   - Provide a video demo of the feature
   - Complete the Data Safety form (be explicit that ingredient text is sent to a third-party AI provider)

2. **Required Documentation**
   - Privacy Policy URL
   - App functionality video
   - Accessibility feature justification

### 12.4 Build Release APK

```bash
flutter build apk --release
```

### 12.5 ProGuard Rules (actual, current)

**`android/app/proguard-rules.pro`**

Empty. It previously held a full set of `-keep`/`-dontwarn` rules for ML Kit's text-recognition classes, but those existed only to support `google_mlkit_text_recognition`, which nothing in the app actually called (Section 6) - removed along with the dependency rather than kept around as dead configuration. `build.gradle.kts` still references this file via `proguardFiles(...)`, so it stays in place (just empty) rather than being deleted; add rules here again if a dependency that needs them gets introduced.

---

## 📚 Additional Resources

### Documentation
- [Android Accessibility Service Guide](https://developer.android.com/guide/topics/ui/accessibility/service)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

### Sample Apps for Testing
- Swiggy Instamart
- Blinkit
- Zepto
- BigBasket

---

## ⚠️ Important Notes

1. **Play Store Approval**: Google has strict policies for accessibility services. Be prepared to justify the use case clearly, provide a demo video, and show privacy compliance.
2. **User Trust**: Be transparent about what data is read and what leaves the device - the in-app privacy notice must match what the code actually does (see [Section 3.2](#32-create-accessibility-service) and [Section 9.2](#92-home-screen-actual-current) for the incident that prompted this rule).
3. **Performance**: Don't scan continuously - only on user action (`isScanning` is reset to `false` immediately after each scan completes).
4. **No automated tests or OCR fallback exist yet** - see Sections 6 and 11 before assuming otherwise.
