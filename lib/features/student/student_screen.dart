import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'data/student_mock.dart';
import 'widgets/graduation_card.dart';
import 'widgets/belt_journey_card.dart';
import '../mascot/data/mascot_mock.dart';
import '../mascot/widgets/mascot_card.dart';
import '../../core/widgets/graduation_belt_widget.dart';
import '../graduation/data/mock/student_graduation_progress_mock.dart';
import '../graduation/models/belt_color.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = mockStudent;
    final mascot = mascots.first;
    final monthlyProgress = student.monthlyTrainings / student.monthlyGoal;

    return Scaffold(
      backgroundColor: AppColors.background,
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
              'Bom dia, ${student.name} 👋',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada treino aproxima você da sua próxima evolução.',
              style: TextStyle(fontSize: 18, color: AppColors.grey),
            ),
            const SizedBox(height: 24),

            MascotCard(mascot: mascot),
            const SizedBox(height: 24),

            const BeltJourneyCard(),

            const SizedBox(height: 18),

            const Text(
  'Minha graduação',
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

            GraduationCard(student: student),

            const SizedBox(height: 18),

            _InfoCard(
              title: '🔥 Meta do mês',
              subtitle:
                  '${student.monthlyTrainings} / ${student.monthlyGoal} treinos',
              progress: monthlyProgress,
              color: AppColors.brandPrimary,
            ),

            const SizedBox(height: 18),

            _SimpleCard(
              title: '🏆 Próxima conquista',
              text:
                  '${student.nextAchievement} • ${(student.achievementProgress * 100).round()}%',
            ),

            const SizedBox(height: 18),

            _SimpleCard(
              title: '🔥 Sequência atual',
              text: '${student.streak} treinos consecutivos',
            ),

            const SizedBox(height: 18),

            _SimpleCard(
              title: '📅 Próximo treino',
              text: '${student.nextTraining}\n${student.teacherName}',
            ),

            const SizedBox(height: 18),

            _SimpleCard(
              title: '💬 Frase do dia',
              text: student.quote,
            ),
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

  const _SimpleCard({
    required this.title,
    required this.text,
  });

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
          Text(
            text,
            style: const TextStyle(fontSize: 17, height: 1.4),
          ),
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
        color: Colors.black.withOpacity(0.08),
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