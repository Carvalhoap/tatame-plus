import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'screens/teacher_check_in_screen.dart';

class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Painel do Professor'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👨‍🏫 Bem-vindo, professor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aqui você acompanhará presenças, metas e evolução dos alunos.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherCheckInScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Abrir Check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}