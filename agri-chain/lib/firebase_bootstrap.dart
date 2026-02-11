import 'firebase_bootstrap_web.dart'
    if (dart.library.io) 'firebase_bootstrap_io.dart' as impl;

class FirebaseBootstrap {
  static Future<void> initialize() {
    return impl.initializeFirebase();
  }
}
