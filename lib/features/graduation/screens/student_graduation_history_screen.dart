import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../student/models/student.dart';
import '../models/student_graduation_history.dart';
import '../models/student_graduation_progress.dart';
import '../repository/student_graduation_history_repository.dart';

class StudentGraduationHistoryScreen extends StatefulWidget {
  final Student student;
  final StudentGraduationProgress? currentProgress;
  final String? currentStageName;

  const StudentGraduationHistoryScreen({
    super.key,
    required this.student,
    required this.currentProgress,
    required this.currentStageName,
  });

  @override
  State<StudentGraduationHistoryScreen> createState() =>
      _StudentGraduationHistoryScreenState();
}

class _StudentGraduationHistoryScreenState
    extends State<StudentGraduationHistoryScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<StudentGraduationHistory> history = [];
  int currentStageAttendances = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadHistory());
  }

  Future<void> loadHistory() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sessão não encontrada.';
      });
      return;
    }

    try {
      final historyRepository = context
          .read<StudentGraduationHistoryRepository>();

      final attendanceRepository = context.read<AttendanceRepository>();

      final loadedHistory = await historyRepository.getByStudent(
        academyId: currentUser.academyId,
        studentId: widget.student.id,
      );

      var loadedCurrentAttendances = 0;

      final currentProgress = widget.currentProgress;

      if (currentProgress != null) {
        final attendances = await attendanceRepository.getAttendancesByStudent(
          academyId: currentUser.academyId,
          studentId: widget.student.id,
          start: currentProgress.stageStartedAt,
          end: DateTime.now().add(const Duration(days: 1)),
        );

        loadedCurrentAttendances = attendances
            .where((item) => item.isValid)
            .length;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        history = loadedHistory;
        currentStageAttendances = loadedCurrentAttendances;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar o histórico: $error';
      });
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Histórico de graduações'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gracieRed,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sua evolução no Jiu-Jitsu',
                  style: TextStyle(fontSize: 16, color: AppColors.grey),
                ),
                const SizedBox(height: 24),

                if (widget.currentProgress != null)
                  _HistoryCard(
                    stageName: widget.currentStageName ?? 'Graduação atual',
                    period:
                        'Desde ${formatDate(widget.currentProgress!.stageStartedAt)}',
                    attendances: currentStageAttendances,
                    isCurrent: true,
                  ),

                if (history.isNotEmpty) const SizedBox(height: 14),

                ...history.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HistoryCard(
                      stageName: item.stageName,
                      period:
                          '${formatDate(item.startedAt)} → ${formatDate(item.endedAt)}',
                      attendances: item.validAttendances,
                      isCurrent: false,
                      approvedByName: null,
                      observation: item.observation,
                    ),
                  ),
                ),

                if (history.isEmpty && widget.currentProgress == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Nenhum histórico de graduação disponível.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.grey, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String stageName;
  final String period;
  final int attendances;
  final bool isCurrent;
  final String? approvedByName;
  final String? observation;

  const _HistoryCard({
    required this.stageName,
    required this.period,
    required this.attendances,
    required this.isCurrent,
    this.approvedByName,
    this.observation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: isCurrent
            ? Border.all(color: AppColors.brandPrimary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCurrent ? Icons.radio_button_checked : Icons.check_circle_outline,
            color: isCurrent ? AppColors.brandPrimary : AppColors.success,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stageName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCurrent ? 'Graduação atual' : 'Graduação concluída',
                  style: TextStyle(
                    color: isCurrent ? AppColors.brandPrimary : AppColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(period, style: const TextStyle(color: AppColors.grey)),
                const SizedBox(height: 8),
                Text(
                  '$attendances treinos nesta graduação',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (approvedByName != null && approvedByName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Graduado por: $approvedByName',
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (observation != null && observation!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Observação',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    observation!,
                    style: const TextStyle(color: AppColors.grey, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
