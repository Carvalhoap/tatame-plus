import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../admin/screens/admin_home_screen.dart';
import '../../guardian/screens/guardian_home_screen.dart';
import '../../student/student_home_screen.dart';
import '../../teacher/teacher_home_screen.dart';
import '../repository/auth_repository.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';

class SessionRouter extends StatefulWidget {
  const SessionRouter({super.key});

  @override
  State<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<SessionRouter> {
  bool isRestoringSession = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreSession();
    });
  }

  Future<void> restoreSession() async {
    final authRepository = context.read<AuthRepository>();
    final sessionService = context.read<SessionService>();

    try {
      final user = await authRepository.restoreSession();

      if (mounted && user != null) {
        sessionService.startSession(user);
      }
    } catch (error, stackTrace) {
      debugPrint('Não foi possível restaurar a sessão.');
      debugPrint('Erro: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (mounted) {
      setState(() {
        isRestoringSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isRestoringSession) {
      return const _SessionLoadingScreen();
    }

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
            return const GuardianHomeScreen();

          case null:
            return const LoginScreen();
        }
      },
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Carregando Tatame+...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
