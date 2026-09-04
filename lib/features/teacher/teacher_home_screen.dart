import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'screens/teacher_check_in_screen.dart';
import '../graduation/screens/graduation_attention_screen.dart';
import '../../core/widgets/app_drawer.dart';
import '../attendance/screens/attendance_reports_screen.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
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
              'Acompanhe suas turmas, chamadas e a evolução dos alunos.',
              style: TextStyle(fontSize: 18, height: 1.4),
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
                label: const Text(
                  'Abrir Check-in',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GraduationAttentionScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.sports_martial_arts),
                label: const Text(
                  'Acompanhamento de graduação',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceReportsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text(
                  'Relatório de presenças',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
