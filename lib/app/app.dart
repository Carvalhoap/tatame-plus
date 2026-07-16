import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';

import '../features/auth/data/mock/auth_mock_repository.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/services/session_service.dart';
import '../features/auth/screens/session_router.dart';

import '../features/student/data/mock/student_mock_repository.dart';
import '../features/student/repository/student_repository.dart';

import '../features/attendance/data/mock/attendance_mock_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';

import '../features/attendance/data/mock/check_in_session_mock_repository.dart';
import '../features/attendance/repository/check_in_session_repository.dart';

import '../features/teacher/controllers/teacher_check_in_controller.dart';

class TatamePlusApp extends StatelessWidget {
  const TatamePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        /// -------------------------
        /// AUTH
        /// -------------------------

        Provider<AuthRepository>(
          create: (_) => AuthMockRepository(),
        ),

        ChangeNotifierProvider(
          create: (_) => SessionService(),
        ),

        /// -------------------------
        /// STUDENTS
        /// -------------------------

        Provider<StudentRepository>(
          create: (_) => StudentMockRepository(),
        ),

        /// -------------------------
        /// ATTENDANCE
        /// -------------------------

        Provider<AttendanceRepository>(
          create: (_) => AttendanceMockRepository(),
        ),

        ChangeNotifierProvider<CheckInSessionRepository>(
          create: (_) => CheckInSessionMockRepository(),
        ),

        /// -------------------------
        /// TEACHER
        /// -------------------------

        ChangeNotifierProxyProvider<
            CheckInSessionRepository,
            TeacherCheckInController>(
          create: (context) => TeacherCheckInController(
            repository: context.read<CheckInSessionRepository>(),
          ),
          update: (_, repository, controller) {
            return controller ??
                TeacherCheckInController(
                  repository: repository,
                );
          },
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tatame+',
        theme: AppTheme.light,
        home: const SessionRouter(),
      ),
    );
  }
}