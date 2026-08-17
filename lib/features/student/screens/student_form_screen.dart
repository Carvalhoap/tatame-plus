import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../classroom/models/classroom.dart';
import '../../classroom/repository/classroom_repository.dart';
import '../../graduation/models/graduation_program.dart';
import '../../graduation/models/graduation_stage.dart';
import '../../graduation/repository/graduation_program_repository.dart';
import '../../graduation/models/student_graduation_progress.dart';
import '../../graduation/repository/student_graduation_progress_repository.dart';
import '../../users/models/academy_member.dart';
import '../../users/repository/user_repository.dart';
import '../models/student.dart';
import '../repository/student_repository.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

  bool get isEditing => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  List<Classroom> classrooms = [];
  List<GraduationProgram> graduationPrograms = [];
  List<AcademyMember> studentUsers = [];

  final Set<String> selectedClassroomIds = {};

  String? userId;
  String? graduationProgramId;
  String? currentGraduationStageId;

  DateTime? birthDate;
  DateTime? currentGraduationStageDate;
  DateTime? jiuJitsuStartDate;
  DateTime? academyJoinDate;

  StudentStatus status = StudentStatus.active;

  bool isLoadingReferences = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    _loadStudentValues();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadReferences());
  }

  void _loadStudentValues() {
    final student = widget.student;

    if (student == null) {
      return;
    }

    nameController.text = student.fullName;
    phoneController.text = student.phone ?? '';
    emailController.text = student.email ?? '';

    userId = student.userId;
    graduationProgramId = student.graduationProgramId;

    birthDate = student.birthDate;
    jiuJitsuStartDate = student.jiuJitsuStartDate;
    academyJoinDate = student.academyJoinDate;

    selectedClassroomIds
      ..clear()
      ..addAll(student.classroomIds);

    status = student.status;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> loadReferences() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoadingReferences = false;
      });

      return;
    }

    try {
      final results = await Future.wait([
        context.read<ClassroomRepository>().getClassrooms(
          academyId: currentUser.academyId,
          includeInactive: false,
        ),
        context.read<GraduationProgramRepository>().getActivePrograms(
          academyId: currentUser.academyId,
        ),
        context.read<UserRepository>().getAcademyMembers(
          academyId: currentUser.academyId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final members = results[2] as List<AcademyMember>;

      StudentGraduationProgress? graduationProgress;

      if (widget.student != null) {
        graduationProgress = await context
            .read<StudentGraduationProgressRepository>()
            .getByStudent(
              academyId: currentUser.academyId,
              studentId: widget.student!.id,
            );

        if (!mounted) {
          return;
        }
      }

      setState(() {
        classrooms = results[0] as List<Classroom>;

        graduationPrograms = results[1] as List<GraduationProgram>;

        if (graduationProgress != null) {
          graduationProgramId = graduationProgress.graduationProgramId;
          currentGraduationStageId = graduationProgress.currentStageId;
          currentGraduationStageDate = graduationProgress.stageStartedAt;
        } else if (!widget.isEditing &&
            birthDate != null &&
            graduationProgramId == null) {
          graduationProgramId = _suggestGraduationProgramId(birthDate!);
        }

        studentUsers = members
            .where(
              (member) =>
                  member.isActive &&
                  member.status == 'active' &&
                  member.hasRole('student'),
            )
            .toList();

        studentUsers.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );

        isLoadingReferences = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingReferences = false;
      });

      _showError('Não foi possível carregar os dados: $error');
    }
  }

  GraduationProgram? get selectedGraduationProgram {
    final programId = graduationProgramId;

    if (programId == null) {
      return null;
    }

    for (final program in graduationPrograms) {
      if (program.id == programId) {
        return program;
      }
    }

    return null;
  }

  List<GraduationStage> get availableGraduationStages {
    final program = selectedGraduationProgram;

    if (program == null) {
      return const [];
    }

    final result = List<GraduationStage>.of(program.stages)
      ..sort((a, b) => a.order.compareTo(b.order));

    return result;
  }

  Future<void> selectCurrentGraduationStageDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: currentGraduationStageDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        currentGraduationStageDate = result;
      });
    }
  }

  Future<void> selectBirthDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        birthDate = result;
        graduationProgramId = _suggestGraduationProgramId(result);
      });
    }
  }

  String? _suggestGraduationProgramId(DateTime dateOfBirth) {
    final today = DateTime.now();

    var age = today.year - dateOfBirth.year;

    final birthdayHasOccurred =
        today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);

    if (!birthdayHasOccurred) {
      age--;
    }

    final desiredAudience = age >= 16
        ? GraduationAudience.adult
        : GraduationAudience.kids;

    for (final program in graduationPrograms) {
      if (program.audience == desiredAudience) {
        return program.id;
      }
    }

    return graduationProgramId;
  }

  Future<void> selectJiuJitsuStartDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: jiuJitsuStartDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        jiuJitsuStartDate = result;
      });
    }
  }

  Future<void> selectAcademyJoinDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: academyJoinDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        academyJoinDate = result;
      });
    }
  }

  Future<void> _saveGraduationProgress({
    required String studentId,
    required String academyId,
  }) async {
    final programId = graduationProgramId;
    final stageId = currentGraduationStageId;

    if (programId == null || stageId == null) {
      return;
    }

    final progressRepository = context
        .read<StudentGraduationProgressRepository>();

    StudentGraduationProgress? existingProgress;

    if (widget.isEditing) {
      existingProgress = await progressRepository.getByStudent(
        academyId: academyId,
        studentId: studentId,
      );
    }

    await progressRepository.saveProgress(
      progress: StudentGraduationProgress(
        id: studentId,
        academyId: academyId,
        studentId: studentId,
        graduationProgramId: programId,
        currentStageId: stageId,
        stageStartedAt:
            currentGraduationStageDate ?? academyJoinDate ?? DateTime.now(),
        validAttendances: existingProgress?.validAttendances ?? 0,
        stripes: existingProgress?.stripes ?? const [],
        estimatedCompletionDate: existingProgress?.estimatedCompletionDate,
        approvedByTeacher: existingProgress?.approvedByTeacher ?? false,
      ),
    );
  }

  Future<void> save() async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      _showError('Sua sessão não está disponível.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final repository = context.read<StudentRepository>();

      if (widget.isEditing) {
        await repository.updateStudent(
          academyId: currentUser.academyId,
          studentId: widget.student!.id,
          userId: userId,
          fullName: nameController.text.trim(),
          birthDate: birthDate,
          phone: _optional(phoneController.text),
          email: _optional(emailController.text),
          photoUrl: widget.student!.photoUrl,
          graduationProgramId: graduationProgramId,
          jiuJitsuStartDate: jiuJitsuStartDate,
          academyJoinDate: academyJoinDate,
          classroomIds: selectedClassroomIds.toList(growable: false),
          guardianIds: widget.student!.guardianIds,
          status: status,
          updatedBy: currentUser.id,
        );

        await _saveGraduationProgress(
          studentId: widget.student!.id,
          academyId: currentUser.academyId,
        );
      } else {
        final studentId = await repository.createStudent(
          academyId: currentUser.academyId,
          userId: userId,
          fullName: nameController.text.trim(),
          birthDate: birthDate,
          phone: _optional(phoneController.text),
          email: _optional(emailController.text),
          photoUrl: null,
          graduationProgramId: graduationProgramId,
          jiuJitsuStartDate: jiuJitsuStartDate,
          academyJoinDate: academyJoinDate,
          classroomIds: selectedClassroomIds.toList(growable: false),
          guardianIds: const [],
          status: status,
          createdBy: currentUser.id,
        );
        await _saveGraduationProgress(
          studentId: studentId,
          academyId: currentUser.academyId,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Aluno atualizado com sucesso.'
                : 'Aluno cadastrado com sucesso.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        widget.isEditing
            ? 'Não foi possível atualizar o aluno: $error'
            : 'Não foi possível cadastrar o aluno: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.gracieRed),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar aluno' : 'Novo aluno'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: isLoadingReferences
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  const _SectionTitle(
                    title: 'Dados pessoais',
                    subtitle: 'Informações básicas do aluno.',
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Informe o nome do aluno.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  _DateField(
                    label: 'Data de nascimento',
                    date: birthDate,
                    onTap: selectBirthDate,
                    optional: true,
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'E-mail (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(
                    title: 'Acesso ao Tatame+',
                    subtitle:
                        'Vincule uma conta existente, se o aluno tiver login próprio.',
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String?>(
                    initialValue: userId,
                    decoration: const InputDecoration(
                      labelText: 'Conta de usuário',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem conta própria'),
                      ),
                      ...studentUsers.map(
                        (member) => DropdownMenuItem<String?>(
                          value: member.userId,
                          child: Text(member.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        userId = value;

                        if (value != null) {
                          final member = studentUsers.firstWhere(
                            (item) => item.userId == value,
                          );

                          if (nameController.text.trim().isEmpty) {
                            nameController.text = member.displayName;
                          }

                          if (emailController.text.trim().isEmpty) {
                            emailController.text = member.email;
                          }
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(
                    title: 'Jiu-Jitsu',
                    subtitle: 'Dados esportivos e progressão.',
                  ),

                  const SizedBox(height: 14),

                  _DateField(
                    label: 'Início no Jiu-Jitsu',
                    date: jiuJitsuStartDate,
                    onTap: selectJiuJitsuStartDate,
                    optional: true,
                  ),

                  const SizedBox(height: 14),

                  _DateField(
                    label: 'Entrada na academia',
                    date: academyJoinDate,
                    onTap: selectAcademyJoinDate,
                    optional: true,
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String?>(
                    initialValue: graduationProgramId,
                    decoration: const InputDecoration(
                      labelText: 'Programa de graduação',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem programa definido'),
                      ),
                      ...graduationPrograms.map(
                        (program) => DropdownMenuItem<String?>(
                          value: program.id,
                          child: Text(program.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        graduationProgramId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String?>(
                    initialValue:
                        availableGraduationStages.any(
                          (stage) => stage.id == currentGraduationStageId,
                        )
                        ? currentGraduationStageId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Graduação atual',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem graduação definida'),
                      ),
                      ...availableGraduationStages.map(
                        (stage) => DropdownMenuItem<String?>(
                          value: stage.id,
                          child: Text(stage.name),
                        ),
                      ),
                    ],
                    onChanged: graduationProgramId == null
                        ? null
                        : (value) {
                            setState(() {
                              currentGraduationStageId = value;

                              if (value != null &&
                                  currentGraduationStageDate == null) {
                                currentGraduationStageDate = DateTime.now();
                              }
                            });
                          },
                  ),

                  const SizedBox(height: 14),

                  _DateField(
                    label: 'Data da graduação atual',
                    date: currentGraduationStageDate,
                    onTap: selectCurrentGraduationStageDate,
                    optional: true,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Turmas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (classrooms.isEmpty)
                    const Text(
                      'Nenhuma turma ativa cadastrada.',
                      style: TextStyle(color: AppColors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: classrooms.map((classroom) {
                        final selected = selectedClassroomIds.contains(
                          classroom.id,
                        );

                        return FilterChip(
                          label: Text(classroom.name),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                selectedClassroomIds.add(classroom.id);
                              } else {
                                selectedClassroomIds.remove(classroom.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 28),

                  Card(
                    elevation: 0,
                    color: AppColors.white,
                    child: SwitchListTile(
                      value: status == StudentStatus.active,
                      title: Text(
                        status == StudentStatus.active
                            ? 'Aluno ativo'
                            : 'Aluno inativo',
                      ),
                      onChanged: (value) {
                        setState(() {
                          status = value
                              ? StudentStatus.active
                              : StudentStatus.inactive;
                        });
                      },
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
              onPressed: isSaving ? null : save,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Salvando...' : 'Salvar aluno'),
            ),
          ),
        ),
      ),
    );
  }

  String? _optional(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool optional;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: optional ? '$label (opcional)' : label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(date == null ? 'Não informado' : _formatDate(date!)),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
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
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.grey)),
      ],
    );
  }
}
