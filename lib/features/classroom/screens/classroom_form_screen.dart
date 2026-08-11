import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../users/models/academy_member.dart';
import '../../users/repository/user_repository.dart';
import '../models/classroom.dart';
import '../repository/classroom_repository.dart';

class ClassroomFormScreen extends StatefulWidget {
  final Classroom? classroom;

  const ClassroomFormScreen({super.key, this.classroom});

  bool get isEditing => classroom != null;

  @override
  State<ClassroomFormScreen> createState() => _ClassroomFormScreenState();
}

class _ClassroomFormScreenState extends State<ClassroomFormScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  final List<ClassSchedule> schedules = [];

  List<AcademyMember> teachers = [];

  String? defaultTeacherId;

  bool isActive = true;
  bool isLoading = false;
  bool isLoadingTeachers = true;

  @override
  void initState() {
    super.initState();

    final classroom = widget.classroom;

    if (classroom != null) {
      nameController.text = classroom.name;
      descriptionController.text = classroom.description;
      defaultTeacherId = classroom.defaultTeacherId;
      isActive = classroom.isActive;

      schedules.addAll(classroom.schedules);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => loadTeachers());
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadTeachers() async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      setState(() {
        isLoadingTeachers = false;
      });
      return;
    }

    try {
      final result = await context.read<UserRepository>().getActiveTeachers(
        academyId: currentUser.academyId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        teachers = result;
        isLoadingTeachers = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingTeachers = false;
      });

      _showError('Não foi possível carregar os professores.');
    }
  }

  Future<void> save() async {
    if (isLoading) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      _showError('Sua sessão não está disponível.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final repository = context.read<ClassroomRepository>();

      if (widget.isEditing) {
        await repository.updateClassroom(
          academyId: currentUser.academyId,
          classroomId: widget.classroom!.id,
          name: nameController.text,
          description: descriptionController.text,
          defaultTeacherId: defaultTeacherId,
          schedules: List.unmodifiable(schedules),
          isActive: isActive,
          updatedBy: currentUser.id,
        );
      } else {
        await repository.createClassroom(
          academyId: currentUser.academyId,
          name: nameController.text,
          description: descriptionController.text,
          defaultTeacherId: defaultTeacherId,
          schedules: List.unmodifiable(schedules),
          isActive: isActive,
          createdBy: currentUser.id,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Turma atualizada com sucesso.'
                : 'Turma criada com sucesso.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError('Não foi possível salvar a turma: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> addSchedule() async {
    final result = await showDialog<ClassSchedule>(
      context: context,
      builder: (_) => _ScheduleDialog(teachers: teachers),
    );

    if (result == null) {
      return;
    }

    setState(() {
      schedules.add(result);
      _sortSchedules();
    });
  }

  Future<void> editSchedule(int index) async {
    final result = await showDialog<ClassSchedule>(
      context: context,
      builder: (_) =>
          _ScheduleDialog(teachers: teachers, schedule: schedules[index]),
    );

    if (result == null) {
      return;
    }

    setState(() {
      schedules[index] = result;
      _sortSchedules();
    });
  }

  void removeSchedule(int index) {
    setState(() {
      schedules.removeAt(index);
    });
  }

  void _sortSchedules() {
    schedules.sort((a, b) {
      final day = a.dayOfWeek.compareTo(b.dayOfWeek);

      if (day != 0) {
        return day;
      }

      return a.startTime.compareTo(b.startTime);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.gracieRed),
      );
  }

  AcademyMember? _teacherById(String? userId) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar turma' : 'Nova turma'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            const _SectionTitle(
              title: 'Turma',
              subtitle: 'Defina as informações gerais da turma.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o nome da turma.';
                }

                return null;
              },
              decoration: _inputDecoration(
                label: 'Nome da turma',
                icon: Icons.groups_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              decoration: _inputDecoration(
                label: 'Descrição',
                icon: Icons.description_outlined,
                optional: true,
              ),
            ),
            const SizedBox(height: 14),
            if (isLoadingTeachers)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String?>(
                initialValue: _teacherById(defaultTeacherId) == null
                    ? null
                    : defaultTeacherId,
                decoration: _inputDecoration(
                  label: 'Professor responsável',
                  icon: Icons.school_outlined,
                  optional: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem professor definido'),
                  ),
                  ...teachers.map(
                    (teacher) => DropdownMenuItem<String?>(
                      value: teacher.userId,
                      child: Text(teacher.displayName),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    defaultTeacherId = value;
                  });
                },
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle(
                    title: 'Grade semanal',
                    subtitle: 'Adicione quantos horários forem necessários.',
                  ),
                ),
                IconButton.filled(
                  onPressed: addSchedule,
                  tooltip: 'Adicionar horário',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (schedules.isEmpty)
              const _EmptySchedules()
            else
              ...List.generate(schedules.length, (index) {
                final schedule = schedules[index];

                return _ScheduleCard(
                  schedule: schedule,
                  teacher: _teacherById(schedule.teacherId),
                  onEdit: () => editSchedule(index),
                  onDelete: () => removeSchedule(index),
                );
              }),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              color: AppColors.white,
              child: SwitchListTile(
                value: isActive,
                onChanged: isLoading
                    ? null
                    : (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                title: Text(isActive ? 'Turma ativa' : 'Turma inativa'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.white,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : save,
              icon: const Icon(Icons.save),
              label: Text(isLoading ? 'Salvando...' : 'Salvar turma'),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    bool optional = false,
  }) {
    return InputDecoration(
      labelText: optional ? '$label (opcional)' : label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  final List<AcademyMember> teachers;
  final ClassSchedule? schedule;

  const _ScheduleDialog({required this.teachers, this.schedule});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();

  late int dayOfWeek;
  String? teacherId;

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  bool isActive = true;

  @override
  void initState() {
    super.initState();

    final schedule = widget.schedule;

    nameController.text = schedule?.name ?? '';
    dayOfWeek = schedule?.dayOfWeek ?? 1;
    teacherId = schedule?.teacherId;
    isActive = schedule?.isActive ?? true;

    if (schedule != null) {
      startTime = _parseTime(schedule.startTime);

      if (schedule.endTime != null) {
        endTime = _parseTime(schedule.endTime!);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> selectStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: startTime ?? const TimeOfDay(hour: 20, minute: 0),
    );

    if (result != null) {
      setState(() {
        startTime = result;
      });
    }
  }

  Future<void> selectEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: endTime ?? startTime ?? const TimeOfDay(hour: 21, minute: 0),
    );

    if (result != null) {
      setState(() {
        endTime = result;
      });
    }
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (startTime == null) {
      return;
    }

    Navigator.pop(
      context,
      ClassSchedule(
        id:
            widget.schedule?.id ??
            'schedule_${DateTime.now().microsecondsSinceEpoch}',
        name: nameController.text.trim(),
        dayOfWeek: dayOfWeek,
        startTime: _formatTime(startTime!),
        endTime: endTime == null ? null : _formatTime(endTime!),
        trainingTypeId: widget.schedule?.trainingTypeId,
        teacherId: teacherId,
        isActive: isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.schedule == null ? 'Adicionar horário' : 'Editar horário',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Informe o nome do horário.';
                    }

                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nome do horário',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Dia da semana'),
                  items: List.generate(7, (index) {
                    final day = index + 1;

                    return DropdownMenuItem(
                      value: day,
                      child: Text(_dayName(day)),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        dayOfWeek = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  title: const Text('Horário de início'),
                  subtitle: Text(
                    startTime == null
                        ? 'Não definido'
                        : _formatTime(startTime!),
                  ),
                  onTap: selectStartTime,
                ),
                ListTile(
                  title: const Text('Horário de término'),
                  subtitle: Text(
                    endTime == null ? 'Opcional' : _formatTime(endTime!),
                  ),
                  onTap: selectEndTime,
                ),
                DropdownButtonFormField<String?>(
                  initialValue:
                      widget.teachers.any(
                        (teacher) => teacher.userId == teacherId,
                      )
                      ? teacherId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Professor deste horário',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Usar professor da turma'),
                    ),
                    ...widget.teachers.map(
                      (teacher) => DropdownMenuItem<String?>(
                        value: teacher.userId,
                        child: Text(teacher.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      teacherId = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: save, child: const Text('Salvar')),
      ],
    );
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  static String _dayName(int day) {
    const names = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];

    return names[day - 1];
  }
}

class _ScheduleCard extends StatelessWidget {
  final ClassSchedule schedule;
  final AcademyMember? teacher;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.teacher,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(schedule.name),
        subtitle: Text(
          '${schedule.startTime}'
          '${schedule.endTime == null ? '' : ' - ${schedule.endTime}'}'
          '${teacher == null ? '' : '\n${teacher!.displayName}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySchedules extends StatelessWidget {
  const _EmptySchedules();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nenhum horário cadastrado.'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        Text(subtitle),
      ],
    );
  }
}
