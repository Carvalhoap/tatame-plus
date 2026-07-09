import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/attendance/data/mock/attendance_mock_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';
import '../features/home/home_screen.dart';
import '../features/student/data/mock/student_mock_repository.dart';
import '../features/student/repository/student_repository.dart';

class TatameApp extends StatelessWidget {
  const TatameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StudentRepository>(
          create: (_) => StudentMockRepository(),
        ),
        Provider<AttendanceRepository>(
          create: (_) => AttendanceMockRepository(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tatame+',
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}