import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/graduation_belt_widget.dart';
import '../graduation/data/mock/adult_graduation_program_mock.dart';
import '../graduation/data/mock/student_graduation_progress_mock.dart';
import '../graduation/models/belt_color.dart';
import '../mascot/data/mascot_mock.dart';
import '../mascot/widgets/mascot_card.dart';
import 'data/student_mock.dart';
import 'screens/student_qr_scanner_screen.dart';
import 'widgets/belt_journey_card.dart';
import 'widgets/graduation_card.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = mockStudent;
    const dashboard = mockStudentDashboardData;

    final mascot = mascots.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Minha Jornada'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bom dia, ${student.fullName} ðŸ‘‹',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada treino aproxima vocÃª da sua prÃ³xima evoluÃ§Ã£o.',
              style: TextStyle(fontSize: 18, color: AppColors.grey),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final checkInConfirmed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentQrScannerScreen(),
                    ),
                  );

                  if (checkInConfirmed == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'PresenÃ§a registrada com sucesso! +1 treino.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Registrar presenÃ§a',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gracieRed,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            MascotCard(mascot: mascot),
            const SizedBox(height: 24),
            const BeltJourneyCard(),
            const SizedBox(height: 18),
            const Text(
              'Minha graduaÃ§Ã£o',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GraduationBeltWidget(
              beltColor: BeltColor.white,
              stripes: studentGraduationProgressMock.stripes,
            ),
            const SizedBox(height: 18),
            GraduationCard(
              progress: studentGraduationProgressMock,
              program: adultGraduationProgramMock,
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: 'ðŸ”¥ Meta do mÃªs',
              subtitle:
                  '${dashboard.monthlyTrainings} / '
                  '${dashboard.monthlyGoal} treinos',
              progress: dashboard.monthlyProgress,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: 'ðŸ† PrÃ³xima conquista',
              text:
                  '${dashboard.nextAchievement} â€¢ '
                  '${(dashboard.achievementProgress * 100).round()}%',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: 'ðŸ”¥ SequÃªncia atual',
              text: '${dashboard.streak} treinos consecutivos',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: 'ðŸ“… PrÃ³ximo treino',
              text:
                  '${dashboard.nextTraining}\n'
                  '${dashboard.teacherName}',
            ),
            const SizedBox(height: 18),
            _SimpleCard(title: 'ðŸ’¬ Frase do dia', text: dashboard.quote),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _cardTitleStyle()),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.black12,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final String text;

  const _SimpleCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _cardTitleStyle()),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 17, height: 1.4)),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

TextStyle _cardTitleStyle() {
  return const TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.bold,
    color: AppColors.brandPrimary,
  );
}
