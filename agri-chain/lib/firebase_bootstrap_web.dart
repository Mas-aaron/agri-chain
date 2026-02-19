import 'package:firebase_core/firebase_core.dart';

const String _kFirebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const String _kFirebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const String _kFirebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const String _kFirebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const String _kFirebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const String _kFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');

Future<void> initializeFirebase() async {
  final configured =
      _kFirebaseApiKey.isNotEmpty &&
      _kFirebaseProjectId.isNotEmpty &&
      _kFirebaseAppId.isNotEmpty &&
      _kFirebaseMessagingSenderId.isNotEmpty;

  if (!configured) {
    return;
  }

  final authDomain = _kFirebaseAuthDomain.isEmpty ? null : _kFirebaseAuthDomain;
  final storageBucket = _kFirebaseStorageBucket.isEmpty ? null : _kFirebaseStorageBucket;

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: _kFirebaseApiKey,
      appId: _kFirebaseAppId,
      projectId: _kFirebaseProjectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      messagingSenderId: _kFirebaseMessagingSenderId,
    ),
  );
}
