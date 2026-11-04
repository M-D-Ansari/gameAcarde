import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for GameHub Arcade.
/// Environment credentials are configured via `--dart-define` or injected during deployment.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSy_MOCK_KEY_FOR_LOCAL_DEV'),
    appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:000000000000:web:mock0000000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gamehub-arcade-mock'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'gamehub-arcade-mock.firebaseapp.com'),
    databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: 'https://gamehub-arcade-mock-default-rtdb.firebaseio.com'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gamehub-arcade-mock.firebasestorage.app'),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', defaultValue: 'AIzaSy_MOCK_KEY_FOR_LOCAL_DEV'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '1:000000000000:android:mock0000000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gamehub-arcade-mock'),
    databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: 'https://gamehub-arcade-mock-default-rtdb.firebaseio.com'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gamehub-arcade-mock.firebasestorage.app'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY', defaultValue: 'AIzaSy_MOCK_KEY_FOR_LOCAL_DEV'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '1:000000000000:ios:mock0000000000000000'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '000000000000'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'gamehub-arcade-mock'),
    databaseURL: String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: 'https://gamehub-arcade-mock-default-rtdb.firebaseio.com'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'gamehub-arcade-mock.firebasestorage.app'),
    iosBundleId: 'com.gamehub.miniArcadeHub',
  );
}
