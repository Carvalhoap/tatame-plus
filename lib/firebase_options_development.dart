// File generated for the Tatame+ development environment.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DevelopmentFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase de desenvolvimento não configurado para esta plataforma.',
        );
      default:
        throw UnsupportedError(
          'Plataforma não suportada pelo Firebase de desenvolvimento.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_jH1Vrhfd19Yg2qSyQL9Mg1-h49Q4UT0',
    appId: '1:722951567755:web:24ebd9ee50e5387134d78e',
    messagingSenderId: '722951567755',
    projectId: 'tatame-plus-desenvolvimento',
    authDomain: 'tatame-plus-desenvolvimento.firebaseapp.com',
    storageBucket: 'tatame-plus-desenvolvimento.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvdoBIjx5hlRszaUGavUfWMjTUprT0yX8',
    appId: '1:722951567755:android:919c90c74390c53134d78e',
    messagingSenderId: '722951567755',
    projectId: 'tatame-plus-desenvolvimento',
    storageBucket: 'tatame-plus-desenvolvimento.firebasestorage.app',
  );
}
