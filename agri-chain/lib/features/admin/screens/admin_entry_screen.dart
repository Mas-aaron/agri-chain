import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../config/admin_allowlist.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

class AdminEntryScreen extends StatelessWidget {
  const AdminEntryScreen({super.key});

  bool _isAllowlisted(User user) {
    final email = user.email;
    if (email == null) return false;
    return kAdminAllowlistedEmails.contains(email.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const _FirebaseUnavailableView(error: 'Firebase is not initialized'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FirebaseUnavailableView(error: snapshot.error);
          }

          final user = snapshot.data;
          if (user == null) {
            return const AdminLoginScreen();
          }

          if (!_isAllowlisted(user)) {
            return _NotAuthorizedView(email: user.email);
          }

          return const AdminDashboardScreen();
        },
      ),
    );
  }
}

class _NotAuthorizedView extends StatelessWidget {
  final String? email;
  const _NotAuthorizedView({required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not authorized',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in as: ${email ?? 'Unknown'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'This account is not in the admin allowlist. Update lib/config/admin_allowlist.dart to add your admin email.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _FirebaseUnavailableView extends StatelessWidget {
  final Object? error;
  const _FirebaseUnavailableView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firebase not available',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Admin features require Firebase to be configured for Android/iOS (google-services.json / GoogleService-Info.plist).',
          ),
          const SizedBox(height: 12),
          Text('Error: $error'),
        ],
      ),
    );
  }
}
