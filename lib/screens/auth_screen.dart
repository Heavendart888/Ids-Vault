import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'vault_screen.dart';

class AuthScreen extends StatefulWidget {
  // Flag to check if we are opening fresh or unlocking from the background
  final bool isFromBackground;
  
  const AuthScreen({super.key, this.isFromBackground = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to unlock your Vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && mounted) {
        if (widget.isFromBackground) {
          // If coming from background, just pop the lock screen to reveal the previous screen!
          Navigator.pop(context);
        } else {
          // If fresh start, go to Vault Screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VaultScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint("Auth error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text('Vault Locked', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _authenticate,
              icon: const Icon(Icons.fingerprint, size: 30),
              label: const Text('Unlock', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}