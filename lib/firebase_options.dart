// Hand-written (not `flutterfire configure`-generated) from the
// google-services.json downloaded from the Firebase console — this
// sandbox can't run `flutterfire configure` itself (it needs an
// interactive `firebase login`). Android-only, matching this app's
// android-only platform support (see pubspec.yaml's flutter_launcher_icons
// `ios: false` note). Re-run `flutterfire configure` for a real generated
// version if iOS/web support is ever added.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web — this '
        'app is Android-only.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '$defaultTargetPlatform — this app is Android-only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAPNRkzRtlr5TM6n-cEuR-tt1d1RVSX2aI',
    appId: '1:626419471655:android:feb7855e4901d20b398502',
    messagingSenderId: '626419471655',
    projectId: 'baitulmal-tracking-system',
    storageBucket: 'baitulmal-tracking-system.firebasestorage.app',
  );
}
