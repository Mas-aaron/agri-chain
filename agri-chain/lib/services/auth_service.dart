import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _auth?.currentUser;
  
  Stream<User?> get authStateChanges => 
      _auth?.authStateChanges() ?? const Stream.empty();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase Auth is not initialized');
    
    try {
      final cred = await auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> registerWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase Auth is not initialized');

    try {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: password);
      notifyListeners();
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    notifyListeners();
  }
}
