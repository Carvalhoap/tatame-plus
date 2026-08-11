import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';

import '../features/auth/data/firebase/firebase_auth_repository.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/screens/session_router.dart';
import '../features/auth/services/session_service.dart';

import '../features/student/data/mock/student_mock_repository.dart';
import '../features/student/repository/student_repository.dart';

import '../features/attendance/data/mock/attendance_mock_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';

import '../features/attendance/data/mock/check_in_session_mock_repository.dart';
import '../features/attendance/repository/check_in_session_repository.dart';

import '../features/teacher/controllers/teacher_check_in_controller.dart';

import '../features/users/data/firebase/firestore_user_repository.dart';
import '../features/users/repository/user_repository.dart';

import '../features/classroom/data/firebase/firestore_classroom_repository.dart';
import '../features/classroom/repository/classroom_repository.dart';

import '../features/graduation/data/firebase/firestore_graduation_program_repository.dart';
import '../features/graduation/repository/graduation_program_repository.dart';

import '../features/training_type/data/firebase/firestore_training_type_repository.dart';
import '../features/training_type/repository/training_type_repository.dart';

class TatamePlusApp extends StatelessWidget {
  const TatamePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),

        ChangeNotifierProvider(create: (_) => SessionService()),

        Provider<UserRepository>(create: (_) => FirestoreUserRepository()),

        Provider<ClassroomRepository>(
          create: (_) => FirestoreClassroomRepository(),
        ),

        Provider<GraduationProgramRepository>(
          create: (_) => FirestoreGraduationProgramRepository(),
        ),

        Provider<TrainingTypeRepository>(
          create: (_) => FirestoreTrainingTypeRepository(),
        ),

        Provider<StudentRepository>(create: (_) => StudentMockRepository()),

        Provider<AttendanceRepository>(
          create: (_) => AttendanceMockRepository(),
        ),

        ChangeNotifierProvider<CheckInSessionRepository>(
          create: (_) => CheckInSessionMockRepository(),
        ),

        ChangeNotifierProxyProvider<
          CheckInSessionRepository,
          TeacherCheckInController
        >(
          create: (context) => TeacherCheckInController(
            repository: context.read<CheckInSessionRepository>(),
          ),
          update: (_, repository, controller) {
            return controller ??
                TeacherCheckInController(repository: repository);
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
