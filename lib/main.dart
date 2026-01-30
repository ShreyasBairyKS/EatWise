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
    // Cleanup when app is disposed
    _stopAllServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is being terminated
      _stopAllServices();
    }
  }

  Future<void> _stopAllServices() async {
    try {
      await NativeBridge.hideOverlay();
      await NativeBridge.stopScan();
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatbotController(),
      child: MaterialApp(
        title: 'EatWise',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

