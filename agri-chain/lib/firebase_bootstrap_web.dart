import 'package:firebase_core/firebase_core.dart';

// ── Runtime env overrides (passed via --dart-define at build/run time) ──
const String _kFirebaseApiKey =
    String.fromEnvironment('FIREBASE_API_KEY');
const String _kFirebaseAuthDomain =
    String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const String _kFirebaseProjectId =
    String.fromEnvironment('FIREBASE_PROJECT_ID');
const String _kFirebaseStorageBucket =
    String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const String _kFirebaseMessagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const String _kFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');

// ── Fallback values from Firebase console (same project as Android) ──────
// To get the web AppId:
//   Firebase Console → Project Settings → General → Your apps → Add app → Web
//   Then copy the firebaseConfig block.
//
// Fill these in if you register a web app in the Firebase console:
const String _kFallbackApiKey            = 'AIzaSyCzsadLe76q9qK8OzgmzY6aYAu7A11-c08';
const String _kFallbackProjectId         = 'agri-chain-models';
const String _kFallbackMessagingSenderId = '540713348802';
const String _kFallbackAuthDomain        = 'agri-chain-models.firebaseapp.com';
const String _kFallbackStorageBucket     = 'agri-chain-models.firebasestorage.app';
// Web App ID: set this after adding a Web app in Firebase Console → Project Settings
// Format: '1:540713348802:web:XXXXXXXXXXXXXXXX'
const String _kFallbackWebAppId          = '1:540713348802:web:d7ce41540262036fd7155b';

String _resolve(String envVal, String fallback) =>
    envVal.isNotEmpty ? envVal : fallback;

Future<void> initializeFirebase() async {
  final apiKey         = _resolve(_kFirebaseApiKey,            _kFallbackApiKey);
  final projectId      = _resolve(_kFirebaseProjectId,         _kFallbackProjectId);
  final messagingSenderId = _resolve(_kFirebaseMessagingSenderId, _kFallbackMessagingSenderId);
  final appId          = _resolve(_kFirebaseAppId,             _kFallbackWebAppId);
  final authDomain     = _resolve(_kFirebaseAuthDomain,        _kFallbackAuthDomain);
  final storageBucket  = _resolve(_kFirebaseStorageBucket,     _kFallbackStorageBucket);

  // Web requires all three: apiKey, projectId, AND appId.
  // If appId is empty (web app not registered yet), skip initialization.
  // The login screen will show a "Web demo mode" notice in this case.
  if (apiKey.isEmpty || projectId.isEmpty || appId.isEmpty) return;

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey:            apiKey,
      appId:             appId,
      projectId:         projectId,
      authDomain:        authDomain,
      storageBucket:     storageBucket,
      messagingSenderId: messagingSenderId,
    ),
  );
}
