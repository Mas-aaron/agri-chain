import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/services/verifier_api_service.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/models/verifier_models.dart';
import 'package:agri_chain/screens/verifier/verifier_dashboard.dart';

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

/// Checks the backend to see if the authenticated user is a verifier.
/// If yes, routes to VerifierDashboard; otherwise, to the farmer AppShell.
class _RoleRouter extends StatefulWidget {
  final User user;
  final Widget farmerChild;

  const _RoleRouter({required this.user, required this.farmerChild});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<Map<String, dynamic>?> _lookupFuture;

  @override
  void initState() {
    super.initState();
    _lookupFuture = VerifierApiService().lookupByUserId(widget.user.uid);
  }

  @override
  void didUpdateWidget(covariant _RoleRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _lookupFuture = VerifierApiService().lookupByUserId(widget.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _lookupFuture,
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

        final verifierData = snap.data;
        if (verifierData != null) {
          // User is a verifier — hydrate the provider and show verifier dashboard
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final prov = context.read<VerifierProvider>();
            if (prov.verifier == null || prov.verifier!.userId != widget.user.uid) {
              prov.verifier = Verifier.fromJson(verifierData);
              prov.loadDashboardData();
            }
          });
          return const VerifierDashboard();
        }

        // User is a farmer — show normal app
        return widget.farmerChild;
      },
    );
  }
}
