import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/class_occurrence.dart';
import 'class_occurrence_form_screen.dart';
import '../repository/class_occurrence_repository.dart';

class ClassOccurrencesScreen extends StatefulWidget {
  const ClassOccurrencesScreen({super.key});

  @override
  State<ClassOccurrencesScreen> createState() => _ClassOccurrencesScreenState();
}

class _ClassOccurrencesScreenState extends State<ClassOccurrencesScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<ClassOccurrence> occurrences = [];

  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    startDate = DateTime(now.year, now.month, 1);

    endDate = DateTime(now.year, now.month + 1, 0);

    WidgetsBinding.instance.addPostFrameCallback((_) => loadOccurrences());
  }

  Future<void> loadOccurrences() async {
    final user = context.read<SessionService>().currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sessão não encontrada.';
      });

      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await context
          .read<ClassOccurrenceRepository>()
          .getOccurrencesByPeriod(
            academyId: user.academyId,
            startDate: startDate,
            endDate: endDate,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        occurrences = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar a agenda: $error';
      });
    }
  }

  void previousMonth() {
    setState(() {
      startDate = DateTime(startDate.year, startDate.month - 1, 1);

      endDate = DateTime(startDate.year, startDate.month + 1, 0);
    });

    loadOccurrences();
  }

  void nextMonth() {
    setState(() {
      startDate = DateTime(startDate.year, startDate.month + 1, 1);

      endDate = DateTime(startDate.year, startDate.month + 1, 0);
    });

    loadOccurrences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agenda / Exceções'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassOccurrenceFormScreen(),
            ),
          );

          if (changed == true && mounted) {
            await loadOccurrences();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova ocorrência'),
      ),
      body: RefreshIndicator(
        onRefresh: loadOccurrences,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _MonthSelector(
              date: startDate,
              onPrevious: previousMonth,
              onNext: nextMonth,
            ),
            const SizedBox(height: 20),
            const Text(
              'Alterações da grade',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Substituições, cancelamentos e treinos extraordinários aparecem aqui.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              _MessageCard(icon: Icons.error_outline, message: errorMessage!)
            else if (occurrences.isEmpty)
              const _MessageCard(
                icon: Icons.event_available,
                message: 'Nenhuma exceção ou treino extraordinário neste mês.',
              )
            else
              ...occurrences.map(
                (occurrence) => _OccurrenceCard(
                  occurrence: occurrence,
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ClassOccurrenceFormScreen(occurrence: occurrence),
                      ),
                    );

                    if (changed == true && mounted) {
                      await loadOccurrences();
                    }
                  },
                  onDelete: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Excluir ocorrência'),
                          content: Text(
                            'Deseja realmente excluir "${occurrence.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, false);
                              },
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, true);
                              },
                              child: const Text('Excluir'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed != true || !context.mounted) {
                      return;
                    }

                    final currentUser = context
                        .read<SessionService>()
                        .currentUser;

                    if (currentUser == null) {
                      return;
                    }

                    try {
                      await context
                          .read<ClassOccurrenceRepository>()
                          .deleteOccurrence(
                            academyId: currentUser.academyId,
                            occurrenceId: occurrence.id,
                          );

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ocorrência excluída com sucesso.'),
                        ),
                      );

                      await loadOccurrences();
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Não foi possível excluir: $error'),
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthName(date.month)} ${date.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return months[month - 1];
  }
}

class _OccurrenceCard extends StatelessWidget {
  final ClassOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OccurrenceCard({
    required this.occurrence,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(_statusIcon(occurrence.status))),
        title: Text(
          occurrence.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatDate(occurrence.date)} • '
          '${occurrence.startTime}'
          '${occurrence.endTime == null ? '' : ' - ${occurrence.endTime}'}'
          '\n${_statusName(occurrence.status)}'
          '${occurrence.note.isEmpty ? '' : '\n${occurrence.note}'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Excluir ocorrência',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  static IconData _statusIcon(ClassOccurrenceStatus status) {
    switch (status) {
      case ClassOccurrenceStatus.scheduled:
        return Icons.event_available;

      case ClassOccurrenceStatus.substituted:
        return Icons.swap_horiz;

      case ClassOccurrenceStatus.cancelled:
        return Icons.event_busy;

      case ClassOccurrenceStatus.extra:
        return Icons.add_circle_outline;
    }
  }

  static String _statusName(ClassOccurrenceStatus status) {
    switch (status) {
      case ClassOccurrenceStatus.scheduled:
        return 'Aula programada';

      case ClassOccurrenceStatus.substituted:
        return 'Professor substituto';

      case ClassOccurrenceStatus.cancelled:
        return 'Aula cancelada';

      case ClassOccurrenceStatus.extra:
        return 'Treino extraordinário';
    }
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
