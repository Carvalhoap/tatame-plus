import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../users/models/academy_member.dart';
import '../../users/repository/user_repository.dart';
import '../models/classroom.dart';
import '../repository/classroom_repository.dart';
import 'classroom_form_screen.dart';

class ClassroomsScreen extends StatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  State<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends State<ClassroomsScreen> {
  Future<_ClassroomsData>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<_ClassroomsData> load() async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      throw StateError('Nenhum usuário autenticado foi encontrado.');
    }

    final classroomsFuture = context.read<ClassroomRepository>().getClassrooms(
      academyId: currentUser.academyId,
    );

    final teachersFuture = context.read<UserRepository>().getActiveTeachers(
      academyId: currentUser.academyId,
    );

    final classrooms = await classroomsFuture;
    final teachers = await teachersFuture;

    return _ClassroomsData(classrooms: classrooms, teachers: teachers);
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  Future<void> openForm({Classroom? classroom}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClassroomFormScreen(classroom: classroom),
      ),
    );

    if (!mounted) {
      return;
    }

    if (changed == true) {
      reload();
    }
  }

  Future<void> toggleActive(Classroom classroom) async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await context.read<ClassroomRepository>().setClassroomActive(
        academyId: currentUser.academyId,
        classroomId: classroom.id,
        isActive: !classroom.isActive,
        updatedBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível alterar a turma: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Turmas'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova turma'),
      ),
      body: FutureBuilder<_ClassroomsData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: reload);
          }

          final data = snapshot.data!;

          if (data.classrooms.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: data.classrooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final classroom = data.classrooms[index];

                final teacher = data.teacherById(classroom.defaultTeacherId);

                return _ClassroomCard(
                  classroom: classroom,
                  teacher: teacher,
                  onTap: () => openForm(classroom: classroom),
                  onToggleActive: () => toggleActive(classroom),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ClassroomsData {
  final List<Classroom> classrooms;
  final List<AcademyMember> teachers;

  const _ClassroomsData({required this.classrooms, required this.teachers});

  AcademyMember? teacherById(String? userId) {
    if (userId == null) {
      return null;
    }

    for (final teacher in teachers) {
      if (teacher.userId == userId) {
        return teacher;
      }
    }

    return null;
  }
}

class _ClassroomCard extends StatelessWidget {
  final Classroom classroom;
  final AcademyMember? teacher;

  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  const _ClassroomCard({
    required this.classroom,
    required this.teacher,
    required this.onTap,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final activeSchedules = classroom.schedules
        .where((schedule) => schedule.isActive)
        .toList();

    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      classroom.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: classroom.isActive,
                    onChanged: (_) => onToggleActive(),
                  ),
                ],
              ),
              if (classroom.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(classroom.description),
              ],
              const SizedBox(height: 10),
              Text(
                teacher == null
                    ? 'Professor responsável não definido'
                    : 'Professor: ${teacher!.displayName}',
                style: const TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                '${activeSchedules.length} horário(s) ativo(s)',
                style: const TextStyle(color: AppColors.grey),
              ),
              if (activeSchedules.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...activeSchedules
                    .take(4)
                    .map(
                      (schedule) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${_dayName(schedule.dayOfWeek)} • '
                          '${schedule.startTime}'
                          '${schedule.endTime == null ? '' : ' - ${schedule.endTime}'}'
                          ' • ${schedule.name}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
                    ),
                if (activeSchedules.length > 4)
                  Text(
                    '+ ${activeSchedules.length - 4} outro(s) horário(s)',
                    style: const TextStyle(fontSize: 13, color: AppColors.grey),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _dayName(int day) {
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    if (day < 1 || day > names.length) {
      return '?';
    }

    return names[day - 1];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma turma cadastrada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie a primeira turma e configure a grade semanal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar as turmas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
