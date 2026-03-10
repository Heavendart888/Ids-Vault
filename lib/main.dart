import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
// Note: Adjust this import path if your AuthScreen is in a different folder
import 'screens/auth_screen.dart'; 

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// GLOBAL FLAG: Tells the security system to ignore the background pause
// when the user intentionally opens the camera or file picker.
bool isIntentionalPause = false; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenProtector.preventScreenshotOn();
  runApp(const SecureDocApp());
}

class SecureDocApp extends StatefulWidget {
  const SecureDocApp({super.key});

  @override
  State<SecureDocApp> createState() => _SecureDocAppState();
}

class _SecureDocAppState extends State<SecureDocApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // CRITICAL FIX: Only lock when 'paused' (app put in background).
    if (state == AppLifecycleState.paused) {
      // HALL PASS CHECK: Are we intentionally picking a file/using the camera?
      if (isIntentionalPause) {
        return; // Ignore the background event! Let them pick their file.
      }

      // No hall pass? Lock the app immediately.
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false, 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      title: 'Secure Govt Docs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          centerTitle: true,
        ),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}