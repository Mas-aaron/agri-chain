import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
      // Accessing instance can throw TypeError on Web if uninitialized
      final auth = FirebaseAuth.instance;
      return auth.authStateChanges();
    } catch (e) {
      debugPrint('FirebaseAuth error (web?): $e');
      // Throws, so return an empty stream that yields nothing
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
        
        // If getting the stream failed, assume unauthenticated
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
              return authenticatedChild;
            }
            return unauthenticatedChild;
          },
        );
      },
    );
  }
}
