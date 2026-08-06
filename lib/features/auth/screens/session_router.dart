import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../student/student_home_screen.dart';
import '../../teacher/teacher_home_screen.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import '../../admin/screens/admin_home_screen.dart';

class SessionRouter extends StatelessWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionService>(
      builder: (context, session, _) {
        if (!session.isAuthenticated) {
          return const LoginScreen();
        }

        if (session.activeRole == null) {
          return const RoleSelectionScreen();
        }

        switch (session.activeRole) {
          case UserRole.admin:
          case UserRole.partner:
            return const AdminHomeScreen();

          case UserRole.teacher:
            return const TeacherHomeScreen();

          case UserRole.student:
            return const StudentHomeScreen();

          case UserRole.guardian:
            return const Scaffold(
              body: Center(
                child: Text('Área do responsável em desenvolvimento'),
              ),
            );

          case null:
            return const LoginScreen();
        }
      },
    );
  }
}
