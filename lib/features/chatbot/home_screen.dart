import 'package:flutter/material.dart';
import '../../core/platform_channel.dart';
import 'chat_screen.dart';

/// Home screen with permission setup and service activation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _accessibilityEnabled = false;
  bool _overlayEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recheck permissions when app resumes (user might have changed settings)
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    final accessibility = await NativeBridge.checkAccessibilityPermission();
    final overlay = await NativeBridge.checkOverlayPermission();

    setState(() {
      _accessibilityEnabled = accessibility;
      _overlayEnabled = overlay;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Logo / Hero
                    _buildHero(),

                    const SizedBox(height: 48),

                    // Permission Cards
                    _buildPermissionSection(),

                    const SizedBox(height: 32),

                    // Start Button
                    _buildStartButton(),

                    const SizedBox(height: 16),

                    // Refresh Button
                    Center(
                      child: TextButton.icon(
                        onPressed: _checkPermissions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Permissions'),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Privacy Notice
                    _buildPrivacyNotice(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/logo.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if image not found
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 60,
                  color: Colors.green,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'EatWise',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smart Ingredient Analysis',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Know what you eat while you shop',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Permissions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),

        // Accessibility Permission
        _buildPermissionCard(
          icon: Icons.accessibility_new,
          title: 'Accessibility Service',
          description: 'Reads on-screen text to detect ingredient lists',
          enabled: _accessibilityEnabled,
          onEnable: () async {
            await NativeBridge.openAccessibilitySettings();
          },
        ),

        const SizedBox(height: 12),

        // Overlay Permission
        _buildPermissionCard(
          icon: Icons.layers,
          title: 'Display Over Apps',
          description: 'Shows the floating scan button',
          enabled: _overlayEnabled,
          onEnable: () async {
            await NativeBridge.openOverlaySettings();
          },
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool enabled,
    required VoidCallback onEnable,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enabled ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: enabled ? Colors.green : Colors.grey,
              ),
            ),

            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Status / Button
            if (enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Enabled',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: onEnable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Enable'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final allPermissionsGranted = _accessibilityEnabled && _overlayEnabled;

    return ElevatedButton(
      onPressed: allPermissionsGranted ? _startService : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: allPermissionsGranted ? 2 : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allPermissionsGranted ? Icons.play_arrow : Icons.lock,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            allPermissionsGranted ? 'Start EatWise' : 'Enable Permissions First',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We only read text when you tap scan. No data is stored or shared.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startService() async {
    // Show overlay
    await NativeBridge.showOverlay();

    if (mounted) {
      // Navigate to chat screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
