import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'firebase_options_development.dart';

const firebaseEnvironment = String.fromEnvironment(
  'FIREBASE_ENV',
  defaultValue: 'production',
);

const firebaseAppCheckWebSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_WEB_SITE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = firebaseEnvironment == 'development'
      ? DevelopmentFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: firebaseOptions);
  await _activateFirebaseAppCheck();

  final isDevelopment = firebaseEnvironment == 'development';

  runApp(TatamePlusApp(isDevelopment: isDevelopment));
}

Future<void> _activateFirebaseAppCheck() async {
  WebProvider? webProvider;

  if (kIsWeb) {
    if (kDebugMode) {
      webProvider = WebDebugProvider();
    } else {
      if (firebaseAppCheckWebSiteKey.isEmpty) {
        throw StateError(
          'Defina FIREBASE_APP_CHECK_WEB_SITE_KEY no build Web.',
        );
      }

      webProvider = ReCaptchaEnterpriseProvider(firebaseAppCheckWebSiteKey);
    }
  }

  await FirebaseAppCheck.instance.activate(
    providerWeb: webProvider,
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );
}
