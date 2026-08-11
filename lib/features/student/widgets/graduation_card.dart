import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../graduation/models/graduation_program.dart';
import '../../graduation/models/graduation_stage.dart';
import '../../graduation/models/student_graduation_progress.dart';

class GraduationCard extends StatelessWidget {
  final StudentGraduationProgress progress;
  final GraduationProgram program;

  const GraduationCard({
    super.key,
    required this.progress,
    required this.program,
  });

  @override
  Widget build(BuildContext context) {
    final currentStage = _findStage(progress.currentStageId);

    if (currentStage == null) {
      return _UnavailableGraduationCard(
        message:
            'O estÃ¡gio atual de graduaÃ§Ã£o nÃ£o foi encontrado no programa.',
      );
    }

    final nextStage = currentStage.nextStageId == null
        ? null
        : _findStage(currentStage.nextStageId!);

    final requiredAttendances = currentStage.requiredAttendances;

    final attendanceProgress =
        requiredAttendances == null || requiredAttendances <= 0
        ? null
        : (progress.validAttendances / requiredAttendances).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ðŸ¥‹ PrÃ³xima graduaÃ§Ã£o',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nextStage == null
                ? currentStage.name
                : '${currentStage.name} â†’ ${nextStage.name}',
            style: const TextStyle(fontSize: 18),
          ),
          if (attendanceProgress != null) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: attendanceProgress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(20),
              backgroundColor: Colors.black12,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 10),
            Text(
              '${progress.validAttendances} / '
              '$requiredAttendances presenÃ§as vÃ¡lidas',
              style: const TextStyle(fontSize: 16),
            ),
          ],
          if (currentStage.minimumDurationMonths != null) ...[
            const SizedBox(height: 12),
            Text(
              'Tempo mÃ­nimo: '
              '${currentStage.minimumDurationMonths} meses',
              style: const TextStyle(color: AppColors.grey),
            ),
          ],
          if (progress.estimatedCompletionDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'PrevisÃ£o: '
              '${_formatDate(progress.estimatedCompletionDate!)}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (progress.approvedByTeacher) ...[
            const SizedBox(height: 10),
            const Text(
              'Aprovado pelo professor',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  GraduationStage? _findStage(String stageId) {
    for (final stage in program.stages) {
      if (stage.id == stageId) {
        return stage;
      }
    }

    return null;
  }

  static String _formatDate(DateTime date) {
    const months = [
      'janeiro',
      'fevereiro',
      'marÃ§o',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${months[date.month - 1]} de ${date.year}';
  }
}

class _UnavailableGraduationCard extends StatelessWidget {
  final String message;

  const _UnavailableGraduationCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.grey)),
    );
  }
}
