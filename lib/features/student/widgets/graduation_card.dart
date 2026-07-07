import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/student.dart';

class GraduationCard extends StatelessWidget {
  final Student student;

  const GraduationCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        student.graduationClassesDone / student.graduationClassesRequired;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🥋 Próxima graduação',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${student.currentBelt} → ${student.nextBelt}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.black12,
            color: AppColors.gracieRed,
          ),
          const SizedBox(height: 10),
          Text(
            '${student.graduationClassesDone} / ${student.graduationClassesRequired} aulas',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'Tempo mínimo: ${student.minimumTime}',
            style: const TextStyle(color: AppColors.grey),
          ),
          Text(
            'Previsão: ${student.estimatedGraduation}',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}