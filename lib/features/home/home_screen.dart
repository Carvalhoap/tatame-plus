import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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

              const Icon(
                Icons.sports_martial_arts,
                size: 100,
                color: AppColors.brandPrimary,
              ),

              const SizedBox(height: 25),

              const Text(
                'Tatame+',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Evolução começa aqui',
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
                  'Sobre o Tatame+',
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
