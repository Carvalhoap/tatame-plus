import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/home/home_screen.dart';

class TatameApp extends StatelessWidget {
  const TatameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tatame+',
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}