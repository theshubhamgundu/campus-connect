import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/auth_provider.dart';
import 'login_screen_fixed.dart';
import 'home_screen.dart' as home_screen;
import 'onboarding/onboarding_screen.dart';

/// Entry point screen that checks for auto-login and onboarding status
class EntryScreen extends StatefulWidget {
  const EntryScreen({Key? key}) : super(key: key);

  @override
  _EntryScreenState createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to ensure context is available
    Future.microtask(() => _checkAuthStatus());
  }

  Future<void> _checkAuthStatus() async {
    // Simulate splash screen delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
      
      debugPrint('Entry Screen: Checking auth status...');
      debugPrint('  Onboarding completed: $hasCompletedOnboarding');
      
      if (!hasCompletedOnboarding) {
        // First time user - show onboarding
        debugPrint('  → Navigating to onboarding');
        _navigateToOnboarding();
      } else {
        // Check if user can auto-login
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final canAutoLogin = await authProvider.canAutoLogin();
        
        debugPrint('  Can auto-login: $canAutoLogin');

        if (!mounted) return;

        if (canAutoLogin) {
          // Try to auto-login
          try {
            debugPrint('  → Attempting auto-login...');
            await authProvider.initialize();
            if (!mounted) return;
            
            debugPrint('  Auto-login result: isAuthenticated=${authProvider.isAuthenticated}');
            
            if (authProvider.isAuthenticated) {
              debugPrint('  → Navigating to home');
              _navigateToHome();
            } else {
              debugPrint('  → Navigating to login');
              _navigateToLogin();
            }
          } catch (e) {
            debugPrint('  Auto-login error: $e');
            if (mounted) {
              _navigateToLogin();
            }
          }
        } else {
          // Not logged in, show login screen
          debugPrint('  → Navigating to login (no auto-login)');
          _navigateToLogin();
        }
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToOnboarding() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.school,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'CampusNet',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting students and faculty',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

