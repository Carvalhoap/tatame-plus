import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/attendance/data/mock/attendance_mock_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';
import '../features/student/data/mock/student_mock_repository.dart';
import '../features/student/repository/student_repository.dart';
import '../features/about/screens/about_screen.dart';
import '../features/auth/data/mock/auth_mock_repository.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/services/session_service.dart';
import '../features/auth/screens/session_router.dart';
import '../features/attendance/data/mock/check_in_session_mock_repository.dart';
import '../features/attendance/repository/check_in_session_repository.dart';

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
        Provider<AuthRepository>(
          create: (_) => AuthMockRepository(),
        ),
        ChangeNotifierProvider<CheckInSessionRepository>(
          create: (_) => CheckInSessionMockRepository(),
        ),
        ChangeNotifierProvider<SessionService>(
          create: (_) => SessionService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tatame+',
        theme: AppTheme.light,
        routes: {
          '/about': (_) => const AboutScreen(),
        },
        home: const SessionRouter(),
      ),
    );
  }
}