import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/nex_tatame_wordmark.dart';
import '../student/student_home_screen.dart';
import '../teacher/teacher_home_screen.dart';
import 'widgets/botao_perfil.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 60),

              const NexTatameWordmark(height: 118),

              const SizedBox(height: 12),

              const Text(
                'Sua academia. Sua evolução.',
                style: TextStyle(fontSize: 18, color: AppColors.grey),
              ),

              const SizedBox(height: 40),

              BotaoPerfil(
                texto: 'Sou Professor',
                icone: Icons.school,
                cor: AppColors.brandPrimary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherHomeScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              BotaoPerfil(
                texto: 'Sou Aluno',
                icone: Icons.person,
                cor: AppColors.gracieRed,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentHomeScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/about');
                },
                icon: const Icon(Icons.info_outline, color: AppColors.grey),
                label: const Text(
                  'Sobre o NexTatame',
                  style: TextStyle(
                    color: AppColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
