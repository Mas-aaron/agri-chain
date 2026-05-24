import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agri_chain/services/verifier_api_service.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/models/verifier_models.dart';
import 'package:agri_chain/screens/verifier/verifier_dashboard.dart';
import 'package:agri_chain/features/logistics/screens/job_board_screen.dart';
import 'package:agri_chain/features/logistics/providers/logistics_provider.dart';

class AuthWrapper extends StatelessWidget {
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;

  const AuthWrapper({
    super.key,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
  });

  Future<Stream<User?>> _getAuthStream() async {
    try {
      if (Firebase.apps.isEmpty) {
        return const Stream.empty();
      }
      final auth = FirebaseAuth.instance;
      return auth.authStateChanges();
    } catch (e) {
      debugPrint('FirebaseAuth error (web?): $e');
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<User?>>(
      future: _getAuthStream(),
      builder: (context, futureSnapshot) {
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (futureSnapshot.hasError || !futureSnapshot.hasData) {
          return unauthenticatedChild;
        }

        return StreamBuilder<User?>(
          stream: futureSnapshot.data,
          builder: (context, streamSnapshot) {
            if (streamSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (streamSnapshot.hasData && streamSnapshot.data != null) {
              // User is authenticated — check role
              return _RoleRouter(
                user: streamSnapshot.data!,
                farmerChild: authenticatedChild,
              );
            }
            return unauthenticatedChild;
          },
        );
      },
    );
  }
}

/// Checks the backend to see if the authenticated user is a verifier or
/// logistics company. Routes accordingly; defaults to the farmer AppShell.
class _RoleRouter extends StatefulWidget {
  final User user;
  final Widget farmerChild;

  const _RoleRouter({required this.user, required this.farmerChild});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<_UserRole> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _resolveRole(widget.user);
  }

  @override
  void didUpdateWidget(covariant _RoleRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _roleFuture = _resolveRole(widget.user);
    }
  }

  /// Resolves the user's role by checking:
  /// 1. SharedPreferences for a saved 'logistics' role (set at registration)
  /// 2. The verifier API
  /// 3. Defaults to farmer
  Future<_UserRole> _resolveRole(User user) async {
    // Check for logistics role saved at registration time
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = user.email ?? '';
      final savedRole = prefs.getString('user_role_$email') ??
          prefs.getString('user_role_${user.uid}');
      if (savedRole == 'logistics') {
        return _UserRole.logistics;
      }
    } catch (_) {}

    // Check verifier API
    try {
      final verifierData = await VerifierApiService().lookupByUserId(user.uid);
      if (verifierData != null) return _UserRole.verifier;
    } catch (_) {}

    return _UserRole.farmer;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UserRole>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking your account...'),
                ],
              ),
            ),
          );
        }

        final role = snap.data ?? _UserRole.farmer;

        switch (role) {
          case _UserRole.verifier:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              final prov = context.read<VerifierProvider>();
              if (prov.verifier == null || prov.verifier!.userId != widget.user.uid) {
                // Re-fetch verifier data to hydrate the provider
                VerifierApiService().lookupByUserId(widget.user.uid).then((data) {
                  if (data != null && context.mounted) {
                    prov.verifier = Verifier.fromJson(data);
                    prov.loadDashboardData();
                  }
                });
              }
            });
            return const VerifierDashboard();

          case _UserRole.logistics:
            // Ensure LogisticsProvider is initialised
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              context.read<LogisticsProvider>().loadJobs(status: 'OPEN');
            });
            return const JobBoardScreen();

          case _UserRole.farmer:
            return widget.farmerChild;
        }
      },
    );
  }
}

enum _UserRole { farmer, verifier, logistics }
