import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'fitness_profile_setup_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Switches between the auth flow and the main app.
/// Handles navigation based on authentication and profile completion status.
/// Uses Consumer2 to listen to BOTH AuthProvider and ProfileProvider changes
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _resolvedRoute;
  bool _isResolving = false;
  String? _lastResolvedUid; // Track which user was last resolved

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset resolved route when dependencies change (e.g., on new login)
    _resolvedRoute = null;
    _lastResolvedUid = null;
  }

  /// Resolve the next route based on auth and profile status
  Future<void> _resolveRoute(AuthProvider authProvider, {bool forceResolve = false}) async {
    if (_isResolving) {
      print('🔄 [AuthGate] Already resolving route...');
      return;
    }

    if (!authProvider.isLoggedIn) {
      print('🔄 [AuthGate] User logged out, showing login screen');
      if (mounted) {
        setState(() {
          _resolvedRoute = 'login';
          _lastResolvedUid = null;
        });
      }
      return;
    }

    final currentUid = authProvider.currentUser?.id;
    // Check if we need to re-resolve (new user, first time, or forced)
    if (forceResolve || currentUid != _lastResolvedUid) {
      _isResolving = true;
      try {
        print('🔍 [AuthGate] Resolving next route for user: $currentUid (forceResolve=$forceResolve)');
        final route = await authProvider.resolveNextRoute();
        
        if (mounted) {
          setState(() {
            _resolvedRoute = route;
            _lastResolvedUid = currentUid;
          });
        }
      } catch (e) {
        print('❌ [AuthGate] Error resolving route: $e');
        if (mounted) {
          setState(() {
            _resolvedRoute = 'fitnessProfileSetup'; // Fallback
          });
        }
      } finally {
        _isResolving = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
    builder: (context, authProvider, _) {
      final currentUid = authProvider.currentUser?.id;
      final profileChanged = authProvider.profileCompletionStatusChanged;
      
      print('🔄 [AuthGate Build] isLoggedIn: ${authProvider.isLoggedIn}, currentUid: $currentUid, resolvedRoute: $_resolvedRoute, lastResolvedUid: $_lastResolvedUid, profileChanged: $profileChanged');

      // User not logged in - show login screen
      if (!authProvider.isLoggedIn) {
        print('❌ [AuthGate] User not logged in. Showing LoginScreen.');
        // Reset route when logging out
        if (_resolvedRoute != null || _lastResolvedUid != null) {
          _resolvedRoute = null;
          _lastResolvedUid = null;
        }
        return const LoginScreen();
      }

      // Check if we need to re-resolve
      // This happens on first load OR when user changes OR when profile completion status changed
      final needsResolve = _resolvedRoute == null || 
                          currentUid != _lastResolvedUid || 
                          profileChanged;
      
      if (needsResolve) {
        print('⏳ [AuthGate] Route needs resolution (needsResolve=$needsResolve, profileChanged=$profileChanged). Scheduling resolution...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Reset the profile changed flag before resolving
            final wasProfileChanged = authProvider.profileCompletionStatusChanged;
            if (wasProfileChanged) {
              authProvider.resetProfileCompletionStatusChanged();
            }
            // Force re-resolve if profile status changed
            _resolveRoute(authProvider, forceResolve: wasProfileChanged);
          }
        });

        return Scaffold(
          backgroundColor: Colors.black87,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Setting up your account...',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Route resolved - navigate accordingly
      print('✅ [AuthGate] Route resolved: $_resolvedRoute');

      switch (_resolvedRoute) {
        case 'dashboard':
          print('🎯 [AuthGate] Navigating to: Dashboard');
          return const MainShell();

        case 'fitnessProfileSetup':
          print('🎯 [AuthGate] Navigating to: Fitness Profile Setup');
          return const FitnessProfileSetupScreen();

        default:
          print('⚠️ [AuthGate] Unknown route: $_resolvedRoute. Defaulting to Profile Setup.');
          return const FitnessProfileSetupScreen();
      }
    },
  );
}