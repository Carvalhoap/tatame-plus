import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/student.dart';
import '../repository/student_repository.dart';
import 'student_form_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Student> students = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadStudents());
  }

  Future<void> loadStudents() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
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
          .read<StudentRepository>()
          .getStudentsByAcademy(currentUser.academyId);

      if (!mounted) {
        return;
      }

      setState(() {
        students = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar os alunos: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStudents = students
        .where((student) => student.isActive)
        .toList();

    final inactiveStudents = students
        .where((student) => !student.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alunos'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const StudentFormScreen()),
          );

          if (changed == true && mounted) {
            await loadStudents();
          }
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo aluno'),
      ),
      body: RefreshIndicator(
        onRefresh: loadStudents,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _SummaryCard(
              total: students.length,
              active: activeStudents.length,
              inactive: inactiveStudents.length,
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              _MessageCard(icon: Icons.error_outline, message: errorMessage!)
            else if (students.isEmpty)
              const _MessageCard(
                icon: Icons.groups_outlined,
                message: 'Nenhum aluno cadastrado nesta academia.',
              )
            else ...[
              if (activeStudents.isNotEmpty) ...[
                const _SectionTitle(title: 'Alunos ativos'),
                const SizedBox(height: 10),
                ...activeStudents.map(
                  (student) => _StudentCard(
                    student: student,
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentFormScreen(student: student),
                        ),
                      );

                      if (changed == true && mounted) {
                        await loadStudents();
                      }
                    },
                  ),
                ),
              ],
              if (inactiveStudents.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Alunos inativos'),
                const SizedBox(height: 10),
                ...inactiveStudents.map(
                  (student) => _StudentCard(
                    student: student,
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentFormScreen(student: student),
                        ),
                      );

                      if (changed == true && mounted) {
                        await loadStudents();
                      }
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: student.isActive
              ? AppColors.brandPrimary
              : AppColors.grey,
          foregroundColor: AppColors.white,
          child: Text(_initials(student.fullName)),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_subtitle(student)),
        trailing: Icon(
          student.isActive ? Icons.check_circle : Icons.pause_circle_outline,
          color: student.isActive ? AppColors.success : AppColors.grey,
        ),
      ),
    );
  }

  static String _subtitle(Student student) {
    final parts = <String>[];

    if (student.email != null && student.email!.isNotEmpty) {
      parts.add(student.email!);
    }

    if (student.classroomIds.isNotEmpty) {
      parts.add('${student.classroomIds.length} turma(s)');
    }

    if (student.hasLogin) {
      parts.add('Com acesso ao app');
    } else {
      parts.add('Sem acesso próprio');
    }

    return parts.join(' • ');
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int active;
  final int inactive;

  const _SummaryCard({
    required this.total,
    required this.active,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Metric(label: 'Total', value: total),
            _Metric(label: 'Ativos', value: active),
            _Metric(label: 'Inativos', value: inactive),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.grey)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.brandPrimary,
      ),
    );
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
