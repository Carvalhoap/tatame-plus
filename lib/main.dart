import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'firebase_options_development.dart';

const firebaseEnvironment = String.fromEnvironment(
  'FIREBASE_ENV',
  defaultValue: 'production',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = firebaseEnvironment == 'development'
      ? DevelopmentFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: firebaseOptions);

  final isDevelopment = firebaseEnvironment == 'development';

  runApp(TatamePlusApp(isDevelopment: isDevelopment));
}
