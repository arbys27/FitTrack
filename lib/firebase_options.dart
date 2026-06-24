import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    } else if (Platform.isAndroid) {
      return android;
    } else if (Platform.isIOS) {
      return ios;
    }
    return web;
  }

  /// Web Firebase configuration for FitTrack app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyArTJsEICnzlPXP9U5w87CjEU5JQcJXoko',
    appId: '1:969875949266:web:32a5c7eb8fd65cc108f0b',
    messagingSenderId: '969875949266',
    projectId: 'fitrackdb',
    authDomain: 'fitrackdb.firebaseapp.com',
    storageBucket: 'fitrackdb.firebasestorage.app',
  );

  /// Android Firebase configuration for FitTrack app
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArTJsEICnzlPXP9U5w87CjEU5JQcJXoko',
    appId: '1:969875949266:android:e22f9b26f67a0077108f0b',
    messagingSenderId: '969875949266',
    projectId: 'fitrackdb',
    storageBucket: 'fitrackdb.firebasestorage.app',
  );

  /// iOS Firebase configuration for FitTrack app (placeholder)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArTJsEICnzlPXP9U5w87CjEU5JQcJXoko',
    appId: '1:969875949266:ios:e22f9b26f67a0077108f0b',
    messagingSenderId: '969875949266',
    projectId: 'fitrackdb',
    storageBucket: 'fitrackdb.firebasestorage.app',
  );
}
