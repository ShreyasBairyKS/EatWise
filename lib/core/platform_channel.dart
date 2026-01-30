import 'package:flutter/services.dart';
import 'constants.dart';

/// Bridge for Flutter ↔ Android native communication
class NativeBridge {
  static const MethodChannel _methodChannel =
      MethodChannel(AppConstants.methodChannel);

  static const EventChannel _eventChannel =
      EventChannel(AppConstants.eventChannel);

  // ========== Commands (Flutter → Android) ==========

  /// Start scanning for ingredients on screen
  static Future<bool> startScan() async {
    try {
      final result = await _methodChannel.invokeMethod('startScan');
      return result == true;
    } catch (e) {
      print('Error starting scan: $e');
      return false;
    }
  }

  /// Stop scanning
  static Future<bool> stopScan() async {
    try {
      final result = await _methodChannel.invokeMethod('stopScan');
      return result == true;
    } catch (e) {
      print('Error stopping scan: $e');
      return false;
    }
  }

  /// Check if Accessibility permission is enabled
  static Future<bool> checkAccessibilityPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod('checkAccessibilityPermission');
      return result == true;
    } catch (e) {
      print('Error checking accessibility permission: $e');
      return false;
    }
  }

  /// Check if Overlay permission is enabled
  static Future<bool> checkOverlayPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod('checkOverlayPermission');
      return result == true;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Open Android Accessibility settings
  static Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }

  /// Open Overlay permission settings
  static Future<void> openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod('openOverlaySettings');
    } catch (e) {
      print('Error opening overlay settings: $e');
    }
  }

  /// Show floating overlay button
  static Future<bool> showOverlay() async {
    try {
      final result = await _methodChannel.invokeMethod('showOverlay');
      return result == true;
    } catch (e) {
      print('Error showing overlay: $e');
      return false;
    }
  }

  /// Hide floating overlay button
  static Future<bool> hideOverlay() async {
    try {
      final result = await _methodChannel.invokeMethod('hideOverlay');
      return result == true;
    } catch (e) {
      print('Error hiding overlay: $e');
      return false;
    }
  }

  // ========== Events (Android → Flutter) ==========

  static Stream<Map<String, dynamic>>? _ingredientStreamInstance;

  /// Stream of ingredient data from accessibility service
  /// Uses a singleton pattern to avoid multiple listeners
  static Stream<Map<String, dynamic>> ingredientStream() {
    _ingredientStreamInstance ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) {
            return Map<String, dynamic>.from(event);
          }
          return <String, dynamic>{'type': 'unknown', 'data': event};
        })
        .asBroadcastStream();
    return _ingredientStreamInstance!;
  }

  /// Check if accessibility service is actually running and ready
  static Future<bool> isServiceReady() async {
    try {
      final result = await _methodChannel.invokeMethod('isServiceReady');
      return result == true;
    } catch (e) {
      print('Error checking service status: $e');
      return false;
    }
  }
}
