# 🍎 EatWise - Implementation Guide

## Background Ingredient Intelligence Chatbot

> A Flutter + Kotlin Android app that uses Accessibility Services to analyze food ingredients in real-time from shopping apps like Swiggy, Blinkit, and Zepto.

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
│   │   ├── platform_channel.dart      # Native bridge
│   │   └── constants.dart
│   ├── features/
│   │   ├── chatbot/
│   │   │   ├── chatbot_overlay.dart
│   │   │   └── chatbot_controller.dart
│   │   ├── scanner/
│   │   │   └── ingredient_parser.dart
│   │   └── analysis/
│   │       └── health_analyzer.dart
│   └── services/
│       ├── ai_service.dart
│       └── web_search_service.dart
├── android/
│   └── app/src/main/
│       ├── kotlin/com/eatwise/
│       │   ├── MainActivity.kt
│       │   ├── IngredientScanner.kt
│       │   ├── IngredientAccessibilityService.kt
│       │   ├── OverlayService.kt
│       │   └── PermissionUtil.kt
│       └── res/xml/
│           └── accessibility_service_config.xml
```

### 1.3 Add Dependencies

**pubspec.yaml**
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  provider: ^6.1.1
  flutter_riverpod: ^2.4.9
  google_mlkit_text_recognition: ^0.11.0
  permission_handler: ^11.1.0
  shared_preferences: ^2.2.2
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

Run:
```bash
flutter pub get
```

---

## 2. Android Configuration

### 2.1 Update `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.eatwise.app"
        minSdkVersion 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation 'com.google.mlkit:text-recognition:16.0.0'
}
```

### 2.2 Update `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    
    <application
        android:label="EatWise"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- Accessibility Service Declaration -->
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
        
        <!-- Overlay Foreground Service -->
        <service
            android:name=".OverlayService"
            android:foregroundServiceType="specialUse"
            android:exported="false" />
            
    </application>
</manifest>
```

### 2.3 Create Accessibility Config

**`android/app/src/main/res/xml/accessibility_service_config.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_description"
    android:accessibilityEventTypes="typeWindowContentChanged|typeViewScrolled|typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:canRetrieveWindowContent="true"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows|flagIncludeNotImportantViews"
    android:notificationTimeout="300"
    android:settingsActivity=".MainActivity" />
```

### 2.4 Add String Resources

**`android/app/src/main/res/values/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">EatWise</string>
    <string name="accessibility_description">
        EatWise reads on-screen text only to analyze food ingredients 
        and provide health insights. No data is stored without your consent.
    </string>
</resources>
```

---

## 3. Accessibility Service Implementation

### 3.1 Create Permission Utility

**`android/app/src/main/kotlin/com/eatwise/PermissionUtil.kt`**

```kotlin
package com.eatwise

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

**`android/app/src/main/kotlin/com/eatwise/IngredientAccessibilityService.kt`**

```kotlin
package com.eatwise

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
    
    // Keyword anchors to detect ingredient sections
    private val ingredientAnchors = listOf(
        "ingredients", "contains", "composition", 
        "made with", "ingredients:", "contents:"
    )
    
    // Stop words to end extraction
    private val stopKeywords = listOf(
        "allergen", "storage", "nutritional", "directions",
        "best before", "manufactured", "packed by", "net weight"
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
        val root = rootInActiveWindow ?: return
        val collectedText = StringBuilder()
        traverseNode(root, collectedText)
        
        val fullText = collectedText.toString()
        val ingredientBlock = extractIngredientBlock(fullText)
        
        if (ingredientBlock.isNotEmpty()) {
            IngredientScanner.sendToFlutter(ingredientBlock)
        }
        
        root.recycle()
    }
    
    private fun traverseNode(node: AccessibilityNodeInfo?, builder: StringBuilder) {
        if (node == null) return
        
        node.text?.let { 
            builder.append(it.toString()).append("\n")
        }
        node.contentDescription?.let {
            builder.append(it.toString()).append("\n")
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            traverseNode(child, builder)
            child?.recycle()
        }
    }
    
    private fun extractIngredientBlock(text: String): String {
        val lowerText = text.lowercase()
        
        // Find ingredient anchor
        var startIndex = -1
        for (anchor in ingredientAnchors) {
            val idx = lowerText.indexOf(anchor)
            if (idx != -1) {
                startIndex = idx
                break
            }
        }
        
        if (startIndex == -1) return ""
        
        // Find end of ingredient section
        var endIndex = text.length
        for (stop in stopKeywords) {
            val idx = lowerText.indexOf(stop, startIndex + 10)
            if (idx != -1 && idx < endIndex) {
                endIndex = idx
            }
        }
        
        return text.substring(startIndex, endIndex).trim()
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service Interrupted")
    }
    
    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
```

### 3.3 Create Ingredient Scanner Controller

**`android/app/src/main/kotlin/com/eatwise/IngredientScanner.kt`**

```kotlin
package com.eatwise

import android.content.Context
import io.flutter.plugin.common.EventChannel

object IngredientScanner {
    
    var eventSink: EventChannel.EventSink? = null
    
    fun start(context: Context) {
        IngredientAccessibilityService.isScanning = true
        
        // Trigger immediate scan
        IngredientAccessibilityService.instance?.processScreen()
    }
    
    fun stop() {
        IngredientAccessibilityService.isScanning = false
    }
    
    fun sendToFlutter(ingredientText: String) {
        val data = mapOf(
            "type" to "ingredientText",
            "data" to ingredientText,
            "timestamp" to System.currentTimeMillis()
        )
        eventSink?.success(data)
    }
    
    fun sendError(code: String, message: String) {
        eventSink?.error(code, message, null)
    }
}
```

---

## 4. Flutter-Kotlin Bridge (MethodChannel)

### 4.1 Update MainActivity

**`android/app/src/main/kotlin/com/eatwise/MainActivity.kt`**

```kotlin
package com.eatwise

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    
    private val METHOD_CHANNEL = "com.eatwise/methods"
    private val EVENT_CHANNEL = "com.eatwise/events"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method Channel for commands
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
                    else -> result.notImplemented()
                }
            }
        
        // Event Channel for streaming results
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
}
```

### 4.2 Create Flutter Platform Channel

**`lib/core/platform_channel.dart`**

```dart
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.eatwise/methods');

  static const EventChannel _eventChannel =
      EventChannel('com.eatwise/events');

  // ========== Commands (Flutter → Android) ==========
  
  static Future<void> startScan() async {
    await _methodChannel.invokeMethod('startScan');
  }

  static Future<void> stopScan() async {
    await _methodChannel.invokeMethod('stopScan');
  }

  static Future<bool> checkAccessibilityPermission() async {
    return await _methodChannel.invokeMethod('checkAccessibilityPermission');
  }

  static Future<bool> checkOverlayPermission() async {
    return await _methodChannel.invokeMethod('checkOverlayPermission');
  }

  static Future<void> openAccessibilitySettings() async {
    await _methodChannel.invokeMethod('openAccessibilitySettings');
  }

  static Future<void> openOverlaySettings() async {
    await _methodChannel.invokeMethod('openOverlaySettings');
  }

  static Future<void> showOverlay() async {
    await _methodChannel.invokeMethod('showOverlay');
  }

  static Future<void> hideOverlay() async {
    await _methodChannel.invokeMethod('hideOverlay');
  }

  // ========== Events (Android → Flutter) ==========
  
  static Stream<Map<String, dynamic>> ingredientStream() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event);
    });
  }
}
```

---

## 5. Floating Overlay UI

### 5.1 Create Overlay Service

**`android/app/src/main/kotlin/com/eatwise/OverlayService.kt`**

```kotlin
package com.eatwise

import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    
    companion object {
        private const val CHANNEL_ID = "eatwise_overlay"
        private const val NOTIFICATION_ID = 1
        
        fun start(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            context.startForegroundService(intent)
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, OverlayService::class.java)
            context.stopService(intent)
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
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "EatWise Overlay",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("EatWise Active")
            .setContentText("Tap the floating icon to scan ingredients")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun showOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 300
        
        // Create floating button
        overlayView = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_search)
            setBackgroundResource(android.R.drawable.btn_default)
            setPadding(20, 20, 20, 20)
        }
        
        // Make draggable and clickable
        setupTouchListener(overlayView!!, params)
        
        windowManager.addView(overlayView, params)
    }
    
    private fun setupTouchListener(view: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = true
        
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                        isClick = false
                    }
                    
                    params.x = initialX + deltaX.toInt()
                    params.y = initialY + deltaY.toInt()
                    windowManager.updateViewLayout(overlayView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isClick) {
                        // Trigger scan
                        IngredientScanner.start(this)
                    }
                    true
                }
                else -> false
            }
        }
    }
    
    override fun onDestroy() {
        overlayView?.let { windowManager.removeView(it) }
        super.onDestroy()
    }
}
```

---

## 6. OCR Fallback with ML Kit

### 6.1 Create OCR Service

**`android/app/src/main/kotlin/com/eatwise/OCRService.kt`**

```kotlin
package com.eatwise

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

object OCRService {
    
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.Builder().build())
    
    fun processImage(bitmap: Bitmap, callback: (String) -> Unit) {
        val image = InputImage.fromBitmap(bitmap, 0)
        
        recognizer.process(image)
            .addOnSuccessListener { result ->
                val fullText = result.textBlocks.joinToString("\n") { it.text }
                callback(fullText)
            }
            .addOnFailureListener { e ->
                IngredientScanner.sendError("OCR_FAILED", e.message ?: "OCR failed")
            }
    }
}
```

### 6.2 Flutter OCR Integration (Optional Direct Use)

**`lib/services/ocr_service.dart`**

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
```

---

## 7. Ingredient Processing Engine

### 7.1 Create Ingredient Parser

**`lib/features/scanner/ingredient_parser.dart`**

```dart
class IngredientParser {
  // Common additive patterns (E-numbers, INS codes)
  static final RegExp additivePattern = RegExp(
    r'(E\d{3,4}[a-z]?|INS\s?\d{3,4})',
    caseSensitive: false,
  );

  // Ingredient separators
  static final RegExp separatorPattern = RegExp(r'[,;|]');

  static List<Ingredient> parse(String rawText) {
    // Clean the text
    String cleaned = rawText
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[()]'), ', ')
        .trim();

    // Split by separators
    List<String> parts = cleaned.split(separatorPattern);

    List<Ingredient> ingredients = [];
    for (var part in parts) {
      String name = part.trim();
      if (name.isEmpty || name.length < 2) continue;

      // Check if it's an additive
      bool isAdditive = additivePattern.hasMatch(name);

      ingredients.add(Ingredient(
        name: _normalizeIngredientName(name),
        isAdditive: isAdditive,
        additiveCode: _extractAdditiveCode(name),
      ));
    }

    return ingredients;
  }

  static String _normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'^\d+\.?\s*'), '') // Remove numbering
        .replaceAll(RegExp(r'\*+'), '') // Remove asterisks
        .trim();
  }

  static String? _extractAdditiveCode(String name) {
    final match = additivePattern.firstMatch(name);
    return match?.group(0)?.toUpperCase();
  }
}

class Ingredient {
  final String name;
  final bool isAdditive;
  final String? additiveCode;

  Ingredient({
    required this.name,
    required this.isAdditive,
    this.additiveCode,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isAdditive': isAdditive,
    'additiveCode': additiveCode,
  };
}
```

### 7.2 Create Local Knowledge Base

**`lib/core/knowledge_base.dart`**

```dart
class IngredientKnowledgeBase {
  static const Map<String, IngredientInfo> database = {
    'sugar': IngredientInfo(
      category: 'Sweetener',
      healthImpact: 'negative',
      concerns: ['Blood sugar spike', 'Weight gain', 'Dental issues'],
      dailyLimit: '25g (WHO recommendation)',
    ),
    'palm oil': IngredientInfo(
      category: 'Fat',
      healthImpact: 'negative',
      concerns: ['High saturated fat', 'Environmental concerns'],
      alternatives: ['Coconut oil', 'Olive oil'],
    ),
    'e621': IngredientInfo(
      category: 'Flavor enhancer',
      healthImpact: 'caution',
      commonName: 'MSG (Monosodium Glutamate)',
      concerns: ['May cause headaches in sensitive individuals'],
    ),
    'e211': IngredientInfo(
      category: 'Preservative',
      healthImpact: 'caution',
      commonName: 'Sodium Benzoate',
      concerns: ['May form benzene with Vitamin C'],
    ),
    // Add more ingredients...
  };

  static IngredientInfo? lookup(String ingredientName) {
    final normalized = ingredientName.toLowerCase().trim();
    return database[normalized];
  }
}

class IngredientInfo {
  final String category;
  final String healthImpact; // positive, neutral, caution, negative
  final String? commonName;
  final List<String> concerns;
  final List<String>? benefits;
  final String? dailyLimit;
  final List<String>? alternatives;

  const IngredientInfo({
    required this.category,
    required this.healthImpact,
    this.commonName,
    this.concerns = const [],
    this.benefits,
    this.dailyLimit,
    this.alternatives,
  });
}
```

---

## 8. AI Backend Integration

### 8.1 Create AI Service

**`lib/services/ai_service.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // Replace with your actual API endpoint
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _apiKey = 'YOUR_API_KEY'; // Use environment variables!

  static Future<HealthAnalysis> analyzeIngredients(
    List<String> ingredients,
    UserProfile? userProfile,
  ) async {
    final prompt = _buildPrompt(ingredients, userProfile);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': '''You are a food ingredient analyst. Analyze the 
            ingredients and provide health insights. Be concise and factual.
            Format response as JSON with: summary, concerns, benefits, 
            overallRating (1-10), recommendations.'''
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return HealthAnalysis.fromJson(jsonDecode(content));
    } else {
      throw Exception('AI analysis failed: ${response.statusCode}');
    }
  }

  static String _buildPrompt(List<String> ingredients, UserProfile? profile) {
    String prompt = 'Analyze these food ingredients:\n${ingredients.join(", ")}';
    
    if (profile != null) {
      prompt += '\n\nUser health profile:';
      if (profile.allergies.isNotEmpty) {
        prompt += '\n- Allergies: ${profile.allergies.join(", ")}';
      }
      if (profile.dietaryRestrictions.isNotEmpty) {
        prompt += '\n- Diet: ${profile.dietaryRestrictions.join(", ")}';
      }
      if (profile.healthConditions.isNotEmpty) {
        prompt += '\n- Health conditions: ${profile.healthConditions.join(", ")}';
      }
    }
    
    return prompt;
  }
}

class HealthAnalysis {
  final String summary;
  final List<String> concerns;
  final List<String> benefits;
  final int overallRating;
  final List<String> recommendations;

  HealthAnalysis({
    required this.summary,
    required this.concerns,
    required this.benefits,
    required this.overallRating,
    required this.recommendations,
  });

  factory HealthAnalysis.fromJson(Map<String, dynamic> json) {
    return HealthAnalysis(
      summary: json['summary'] ?? '',
      concerns: List<String>.from(json['concerns'] ?? []),
      benefits: List<String>.from(json['benefits'] ?? []),
      overallRating: json['overallRating'] ?? 5,
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}

class UserProfile {
  final List<String> allergies;
  final List<String> dietaryRestrictions;
  final List<String> healthConditions;

  UserProfile({
    this.allergies = const [],
    this.dietaryRestrictions = const [],
    this.healthConditions = const [],
  });
}
```

### 8.2 Web Search Fallback

**`lib/services/web_search_service.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchService {
  // Use SerpAPI or similar service
  static const String _searchApiKey = 'YOUR_SERP_API_KEY';

  static Future<String?> searchIngredients(String productName) async {
    final query = Uri.encodeComponent('$productName ingredients list');
    final url = 'https://serpapi.com/search.json?q=$query&api_key=$_searchApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Extract ingredient info from search results
        return _extractIngredientInfo(data);
      }
    } catch (e) {
      print('Web search failed: $e');
    }
    return null;
  }

  static String? _extractIngredientInfo(Map<String, dynamic> searchResults) {
    // Parse search results to find ingredient information
    final organicResults = searchResults['organic_results'] as List?;
    if (organicResults != null && organicResults.isNotEmpty) {
      for (var result in organicResults) {
        final snippet = result['snippet'] as String?;
        if (snippet != null && 
            (snippet.toLowerCase().contains('ingredients') ||
             snippet.toLowerCase().contains('contains'))) {
          return snippet;
        }
      }
    }
    return null;
  }
}
```

---

## 9. Chatbot UI Implementation

### 9.1 Main App Entry

**`lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/chatbot/chatbot_controller.dart';
import 'features/chatbot/home_screen.dart';

void main() {
  runApp(const EatWiseApp());
}

class EatWiseApp extends StatelessWidget {
  const EatWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatbotController(),
      child: MaterialApp(
        title: 'EatWise',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

### 9.2 Home Screen with Permission Setup

**`lib/features/chatbot/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/platform_channel.dart';
import 'chatbot_controller.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _accessibilityEnabled = false;
  bool _overlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final accessibility = await NativeBridge.checkAccessibilityPermission();
    final overlay = await NativeBridge.checkOverlayPermission();
    setState(() {
      _accessibilityEnabled = accessibility;
      _overlayEnabled = overlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍎 EatWise'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero section
            const Icon(Icons.health_and_safety, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Smart Ingredient Analysis',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Get instant health insights while shopping',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Permission cards
            _buildPermissionCard(
              title: 'Accessibility Permission',
              description: 'Required to read ingredient text from shopping apps',
              enabled: _accessibilityEnabled,
              onEnable: () async {
                await NativeBridge.openAccessibilitySettings();
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildPermissionCard(
              title: 'Overlay Permission',
              description: 'Required for floating chatbot icon',
              enabled: _overlayEnabled,
              onEnable: () async {
                await NativeBridge.openOverlaySettings();
              },
            ),
            
            const Spacer(),
            
            // Start button
            ElevatedButton(
              onPressed: _accessibilityEnabled && _overlayEnabled
                  ? () => _startService(context)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Start EatWise',
                style: TextStyle(fontSize: 18),
              ),
            ),
            
            const SizedBox(height: 10),
            
            TextButton(
              onPressed: _checkPermissions,
              child: const Text('Refresh Permissions'),
            ),
            
            // Privacy notice
            const SizedBox(height: 20),
            const Text(
              '🔒 Your data stays private. We only analyze ingredients when you tap the icon.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool enabled,
    required VoidCallback onEnable,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          enabled ? Icons.check_circle : Icons.warning,
          color: enabled ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: enabled
            ? const Text('Enabled', style: TextStyle(color: Colors.green))
            : TextButton(
                onPressed: onEnable,
                child: const Text('Enable'),
              ),
      ),
    );
  }

  Future<void> _startService(BuildContext context) async {
    await NativeBridge.showOverlay();
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }
}
```

### 9.3 Chat Screen

**`lib/features/chatbot/chat_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/platform_channel.dart';
import 'chatbot_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToIngredients();
  }

  void _listenToIngredients() {
    NativeBridge.ingredientStream().listen((event) {
      if (event['type'] == 'ingredientText') {
        final controller = context.read<ChatbotController>();
        controller.processIngredients(event['data']);
      }
    }, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍎 EatWise Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => NativeBridge.startScan(),
            tooltip: 'Scan Now',
          ),
        ],
      ),
      body: Consumer<ChatbotController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              // Chat messages
              Expanded(
                child: controller.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(controller.messages[index]);
                        },
                      ),
              ),
              
              // Loading indicator
              if (controller.isLoading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              
              // Input area
              _buildInputArea(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'Open a shopping app and tap\nthe floating icon to scan ingredients',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatbotController controller) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Ask about ingredients...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.green),
              onPressed: () {
                if (_messageController.text.isNotEmpty) {
                  controller.sendMessage(_messageController.text);
                  _messageController.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    NativeBridge.hideOverlay();
    super.dispose();
  }
}
```

### 9.4 Chatbot Controller

**`lib/features/chatbot/chatbot_controller.dart`**

```dart
import 'package:flutter/foundation.dart';
import '../../services/ai_service.dart';
import '../scanner/ingredient_parser.dart';

class ChatbotController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  Future<void> processIngredients(String rawText) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Parse ingredients
      final ingredients = IngredientParser.parse(rawText);
      final ingredientNames = ingredients.map((i) => i.name).toList();

      // Add user message showing what was detected
      addMessage(ChatMessage(
        text: '📋 Detected ingredients:\n${ingredientNames.join(", ")}',
        isUser: true,
      ));

      // Get AI analysis
      final analysis = await AIService.analyzeIngredients(ingredientNames, null);

      // Build response
      final response = _buildAnalysisResponse(analysis);
      addMessage(ChatMessage(text: response, isUser: false));
      
    } catch (e) {
      addMessage(ChatMessage(
        text: '❌ Analysis failed. Please try again.',
        isUser: false,
      ));
    }

    _isLoading = false;
    notifyListeners();
  }

  String _buildAnalysisResponse(HealthAnalysis analysis) {
    final buffer = StringBuffer();
    
    // Rating emoji
    final ratingEmoji = analysis.overallRating >= 7 
        ? '✅' 
        : analysis.overallRating >= 4 
            ? '⚠️' 
            : '❌';
    
    buffer.writeln('$ratingEmoji Health Score: ${analysis.overallRating}/10');
    buffer.writeln();
    buffer.writeln('📝 ${analysis.summary}');
    
    if (analysis.concerns.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⚠️ Concerns:');
      for (var concern in analysis.concerns) {
        buffer.writeln('• $concern');
      }
    }
    
    if (analysis.benefits.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('✅ Benefits:');
      for (var benefit in analysis.benefits) {
        buffer.writeln('• $benefit');
      }
    }
    
    if (analysis.recommendations.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('💡 Tips:');
      for (var tip in analysis.recommendations) {
        buffer.writeln('• $tip');
      }
    }
    
    buffer.writeln();
    buffer.writeln('ℹ️ This is educational info only. Not medical advice.');
    
    return buffer.toString();
  }

  void sendMessage(String text) {
    addMessage(ChatMessage(text: text, isUser: true));
    
    // TODO: Implement conversational AI for follow-up questions
    addMessage(ChatMessage(
      text: 'I can analyze ingredients when you scan a product. '
            'Tap the scan icon in any shopping app!',
      isUser: false,
    ));
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
```

---

## 10. Privacy & Permissions

### 10.1 Privacy Policy Requirements

Create a privacy policy covering:

1. **Data Collection**: Only ingredient text when user initiates scan
2. **Data Storage**: No screenshots or screen data stored
3. **Data Transmission**: Encrypted API calls only
4. **Third-Party Sharing**: Only anonymized queries to AI service
5. **User Control**: Can disable service anytime

### 10.2 Consent Dialog

**`lib/features/onboarding/consent_dialog.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasConsented = prefs.getBool('user_consented') ?? false;
    
    if (hasConsented) return true;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
    
    if (result == true) {
      await prefs.setBool('user_consented', true);
    }
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.privacy_tip, color: Colors.green),
          SizedBox(width: 8),
          Text('Privacy Notice'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EatWise needs special permissions to help you analyze food ingredients.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('📱 Accessibility Permission'),
            Text(
              'Reads on-screen text ONLY to detect ingredient lists. '
              'We do not access passwords, messages, or personal data.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 12),
            Text('🔲 Overlay Permission'),
            Text(
              'Shows the floating scan button over other apps.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              '✅ What we DO:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            Text('• Analyze ingredients when you tap scan'),
            Text('• Provide health insights'),
            SizedBox(height: 8),
            Text(
              '❌ What we DON\'T do:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Text('• Store screenshots'),
            Text('• Access personal messages'),
            Text('• Track your activity'),
            Text('• Share identifiable data'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}
```

---

## 11. Testing & Debugging

### 11.1 Test Accessibility Service

```bash
# Check if service is running
adb shell dumpsys accessibility | grep -i eatwise

# View accessibility logs
adb logcat | grep -i "EatWiseAccessibility"
```

### 11.2 Test MethodChannel

```dart
// Add to main.dart for testing
void testNativeBridge() async {
  print('Testing accessibility: ${await NativeBridge.checkAccessibilityPermission()}');
  print('Testing overlay: ${await NativeBridge.checkOverlayPermission()}');
}
```

### 11.3 Debug Checklist

- [ ] Accessibility service appears in Android settings
- [ ] Service activates when enabled
- [ ] Floating icon appears and is draggable
- [ ] Tap on icon triggers scan
- [ ] Text extraction works on Swiggy/Blinkit
- [ ] Ingredients parsed correctly
- [ ] AI analysis returns valid response
- [ ] Chat UI updates properly

---

## 12. Deployment Checklist

### 12.1 Pre-Release

- [ ] Remove all debug logs
- [ ] Set `minifyEnabled true` in release build
- [ ] Add ProGuard rules for ML Kit
- [ ] Test on multiple devices
- [ ] Verify all permissions work correctly

### 12.2 Play Store Requirements

1. **Accessibility Service Declaration**
   - Must justify why accessibility is needed
   - Provide video demo of feature
   - Complete Data Safety form

2. **Required Documentation**
   - Privacy Policy URL
   - App functionality video
   - Accessibility feature justification

### 12.3 Build Release APK

```bash
flutter build apk --release
```

### 12.4 ProGuard Rules

**`android/app/proguard-rules.pro`**

```proguard
# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
```

---

## 📚 Additional Resources

### Documentation
- [Android Accessibility Service Guide](https://developer.android.com/guide/topics/ui/accessibility/service)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition)

### Sample Apps for Testing
- Swiggy Instamart
- Blinkit
- Zepto
- BigBasket

---

## 🎯 Milestone Timeline

| Week | Milestone |
|------|-----------|
| 1 | Project setup, Android config, permissions |
| 2 | Accessibility service + text extraction |
| 3 | MethodChannel bridge + Flutter UI |
| 4 | Ingredient parsing + knowledge base |
| 5 | AI integration + chat responses |
| 6 | OCR fallback + edge cases |
| 7 | Testing + bug fixes |
| 8 | Documentation + deployment |

---

## ⚠️ Important Notes

1. **Play Store Approval**: Google has strict policies for accessibility services. Be prepared to:
   - Justify the use case clearly
   - Provide demo video
   - Show privacy compliance

2. **User Trust**: Always be transparent about what data you access

3. **Performance**: Don't scan continuously—only on user action

4. **Fallback**: Always have OCR as backup when accessibility fails

---

*Good luck with your final year project! 🚀*
