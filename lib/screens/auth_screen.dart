import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
// Note: Ensure this imports your actual vault screen correctly
import 'vault_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _errorMessage = ""; 

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = "";
    });

    try {
      final bool isSupported = await auth.isDeviceSupported();
      if (!isSupported) {
        setState(() {
          _errorMessage = "No secure lock screen detected.\nPlease set up a PIN or Fingerprint.";
          _isAuthenticating = false;
        });
        return; 
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to access the Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
          biometricOnly: false, 
        ),
      );

      if (didAuthenticate && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VaultScreen()),
        );
      }
    } on PlatformException catch (e) {
      // SILENT FAIL FOR AUTH_IN_PROGRESS: This stops the loop and red text!
      if (e.code == 'auth_in_progress') {
        return; 
      }
      
      setState(() {
        _errorMessage = "Authentication unavailable.\n(Error: ${e.code})";
      });
      debugPrint("Auth error: $e");
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred.";
      });
      debugPrint("Auth error: $e");
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text('System Locked', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isAuthenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock System', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
