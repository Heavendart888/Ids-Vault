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

class _SecureDocAppState extends State<SecureDocApp>
    with WidgetsBindingObserver {
  
  bool _hasLocked = false;

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

    if (state == AppLifecycleState.resumed) {
      _hasLocked = false;
      return;
    }

    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && !_hasLocked) {
      if (isIntentionalPause) {
        return; 
      }

      _hasLocked = true;

      // FIX: Push AuthScreen on top of the current view instead of destroying the stack
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const PopScope(
            canPop: false, // Prevents Android hardware back-button from bypassing the lock
            child: AuthScreen(isFromBackground: true),
          ),
        ),
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
          // FIX: Set to false to push all titles to the left side
          centerTitle: false, 
        ),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      // Initial launch is NOT from background
      home: const AuthScreen(isFromBackground: false), 
    );
  }
}