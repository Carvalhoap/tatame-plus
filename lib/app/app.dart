import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';

import '../features/auth/data/firebase/firebase_auth_repository.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/screens/session_router.dart';
import '../features/auth/services/session_service.dart';

import '../features/student/data/firebase/firestore_student_repository.dart';
import '../features/student/repository/student_repository.dart';

import '../features/attendance/data/firebase/firestore_attendance_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';

import '../features/attendance/data/firebase/firestore_check_in_session_repository.dart';
import '../features/attendance/repository/check_in_session_repository.dart';

import '../features/teacher/controllers/teacher_check_in_controller.dart';

import '../features/users/data/firebase/firestore_user_repository.dart';
import '../features/users/repository/user_repository.dart';

import '../features/classroom/data/firebase/firestore_classroom_repository.dart';
import '../features/classroom/repository/classroom_repository.dart';

import '../features/graduation/data/firebase/firestore_graduation_program_repository.dart';
import '../features/graduation/repository/graduation_program_repository.dart';
import '../features/graduation/data/firebase/firestore_student_graduation_progress_repository.dart';
import '../features/graduation/repository/student_graduation_progress_repository.dart';
import '../features/graduation/data/firebase/firestore_student_graduation_evaluation_repository.dart';
import '../features/graduation/repository/student_graduation_evaluation_repository.dart';
import '../features/graduation/data/firebase/firestore_student_graduation_history_repository.dart';
import '../features/graduation/repository/student_graduation_history_repository.dart';

import '../features/training_type/data/firebase/firestore_training_type_repository.dart';
import '../features/training_type/repository/training_type_repository.dart';

import '../features/class_occurrence/data/firebase/firestore_class_occurrence_repository.dart';
import '../features/class_occurrence/repository/class_occurrence_repository.dart';

class TatamePlusApp extends StatelessWidget {
  final bool isDevelopment;

  const TatamePlusApp({super.key, required this.isDevelopment});

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

        Provider<StudentGraduationProgressRepository>(
          create: (_) => FirestoreStudentGraduationProgressRepository(),
        ),

        Provider<StudentGraduationEvaluationRepository>(
          create: (_) => FirestoreStudentGraduationEvaluationRepository(),
        ),

        Provider<StudentGraduationHistoryRepository>(
          create: (_) => FirestoreStudentGraduationHistoryRepository(),
        ),

        Provider<TrainingTypeRepository>(
          create: (_) => FirestoreTrainingTypeRepository(),
        ),

        Provider<ClassOccurrenceRepository>(
          create: (_) => FirestoreClassOccurrenceRepository(),
        ),

        Provider<StudentRepository>(
          create: (_) => FirestoreStudentRepository(),
        ),

        Provider<AttendanceRepository>(
          create: (_) => FirestoreAttendanceRepository(),
        ),

        ChangeNotifierProvider<CheckInSessionRepository>(
          create: (_) => FirestoreCheckInSessionRepository(),
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
        title: isDevelopment ? 'Tatame+ Desenvolvimento' : 'Tatame+',
        theme: AppTheme.light,
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();

          if (!isDevelopment) {
            return content;
          }

          return Banner(
            message: 'DESENVOLVIMENTO',
            location: BannerLocation.topEnd,
            color: Colors.orange,
            child: content,
          );
        },
        home: const SessionRouter(),
      ),
    );
  }
}
