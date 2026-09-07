import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

/// One-time privacy consent dialog shown before the permission setup screen.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key});

  /// Returns true if the user has already consented, or consents now.
  /// Shows the dialog at most once per install unless consent is declined.
  static Future<bool> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasConsented = prefs.getBool(AppConstants.prefUserConsented) ?? false;
    if (hasConsented) return true;

    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );

    if (result == true) {
      await prefs.setBool(AppConstants.prefUserConsented, true);
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
              'EatWise needs special permissions to analyze food ingredients while you shop.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('📱 Accessibility Permission'),
            Text(
              'Reads on-screen text only when you tap scan, and only forwards it '
              'if it matches a recognized ingredients list. We do not access '
              'passwords, messages, or other on-screen content.',
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
            Text('• Read on-screen text only when you tap scan'),
            Text('• Send matched ingredient text to our AI service for analysis'),
            Text('• Provide health insights based on that analysis'),
            SizedBox(height: 8),
            Text(
              "❌ What we DON'T do:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Text('• Store screenshots or scanned screen content'),
            Text('• Send anything unrelated to an ingredients list off your device'),
            Text('• Access personal messages or passwords'),
            Text('• Track your activity across apps'),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('I Agree'),
        ),
      ],
    );
  }
}
