import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../graduation/models/student_graduation_history.dart';
import '../../graduation/repository/student_graduation_history_repository.dart';
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
  List<AcademyMember> guardianUsers = [];

  final Set<String> selectedClassroomIds = {};
  final Set<String> selectedGuardianIds = {};

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

    selectedGuardianIds
      ..clear()
      ..addAll(student.guardianIds);

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

        guardianUsers = members
            .where(
              (member) =>
                  member.isActive &&
                  member.status == 'active' &&
                  member.hasRole('guardian'),
            )
            .toList();

        guardianUsers.sort(
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
    required String approvedBy,
  }) async {
    final programId = graduationProgramId;
    final stageId = currentGraduationStageId;

    if (programId == null || stageId == null) {
      return;
    }

    final progressRepository = context
        .read<StudentGraduationProgressRepository>();

    final historyRepository = context
        .read<StudentGraduationHistoryRepository>();

    final attendanceRepository = context.read<AttendanceRepository>();

    StudentGraduationProgress? existingProgress;

    if (widget.isEditing) {
      existingProgress = await progressRepository.getByStudent(
        academyId: academyId,
        studentId: studentId,
      );
    }

    final stageChanged =
        existingProgress != null && existingProgress.currentStageId != stageId;

    var stageStartedAt =
        currentGraduationStageDate ?? academyJoinDate ?? DateTime.now();

    var validAttendances = existingProgress?.validAttendances ?? 0;
    var stripes = existingProgress?.stripes ?? const [];
    var estimatedCompletionDate = existingProgress?.estimatedCompletionDate;
    var approvedByTeacher = existingProgress?.approvedByTeacher ?? false;

    if (stageChanged) {
      final previousProgress = existingProgress;
      final now = DateTime.now();

      final previousStage = graduationPrograms
          .where(
            (program) => program.id == previousProgress.graduationProgramId,
          )
          .expand((program) => program.stages)
          .where((stage) => stage.id == previousProgress.currentStageId)
          .firstOrNull;

      final attendances = await attendanceRepository.getAttendancesByStudent(
        academyId: academyId,
        studentId: studentId,
        start: previousProgress.stageStartedAt,
        end: now.add(const Duration(days: 1)),
      );

      final stageAttendances = attendances
          .where((attendance) => attendance.isValid)
          .length;

      await historyRepository.addHistory(
        history: StudentGraduationHistory(
          id: '',
          academyId: academyId,
          studentId: studentId,
          graduationProgramId: previousProgress.graduationProgramId,
          stageId: previousProgress.currentStageId,
          stageName: previousStage?.name ?? previousProgress.currentStageId,
          startedAt: previousProgress.stageStartedAt,
          endedAt: now,
          validAttendances: stageAttendances,
          approvedBy: approvedBy,
          observation: pendingGraduationObservation,
        ),
      );

      stageStartedAt = now;
      validAttendances = 0;
      stripes = const [];
      estimatedCompletionDate = null;
      approvedByTeacher = false;
    }

    await progressRepository.saveProgress(
      progress: StudentGraduationProgress(
        id: studentId,
        academyId: academyId,
        studentId: studentId,
        graduationProgramId: programId,
        currentStageId: stageId,
        stageStartedAt: stageStartedAt,
        validAttendances: validAttendances,
        stripes: stripes,
        estimatedCompletionDate: estimatedCompletionDate,
        approvedByTeacher: approvedByTeacher,
      ),
    );
  }

  String? pendingGraduationObservation;

  Future<bool> _confirmGraduationChange({
    required String academyId,
    required String studentId,
  }) async {
    pendingGraduationObservation = null;

    final newStageId = currentGraduationStageId;

    if (newStageId == null) {
      return true;
    }

    final progressRepository = context
        .read<StudentGraduationProgressRepository>();

    final existingProgress = await progressRepository.getByStudent(
      academyId: academyId,
      studentId: studentId,
    );

    if (existingProgress == null ||
        existingProgress.currentStageId == newStageId) {
      return true;
    }

    final previousStage = graduationPrograms
        .where((program) => program.id == existingProgress.graduationProgramId)
        .expand((program) => program.stages)
        .where((stage) => stage.id == existingProgress.currentStageId)
        .firstOrNull;

    final nextStage = graduationPrograms
        .expand((program) => program.stages)
        .where((stage) => stage.id == newStageId)
        .firstOrNull;

    if (!mounted) {
      return false;
    }

    final observationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar gradua\u00e7\u00e3o'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voc\u00ea est\u00e1 prestes a alterar a gradua\u00e7\u00e3o de '
                  '${widget.student?.fullName ?? nameController.text.trim()}.\n\n'
                  '${previousStage?.name ?? 'Gradua\u00e7\u00e3o atual'}\n'
                  '\u2192\n'
                  '${nextStage?.name ?? 'Nova gradua\u00e7\u00e3o'}\n\n'
                  'Essa altera\u00e7\u00e3o ser\u00e1 registrada no hist\u00f3rico do aluno.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: observationController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Observa\u00e7\u00e3o (opcional)',
                    hintText:
                        'Ex.: Excelente evolu\u00e7\u00e3o t\u00e9cnica e comprometimento.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final observation = observationController.text.trim();

                pendingGraduationObservation = observation.isEmpty
                    ? null
                    : observation;

                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmar gradua\u00e7\u00e3o'),
            ),
          ],
        );
      },
    );

    observationController.dispose();

    if (confirmed != true) {
      pendingGraduationObservation = null;
      return false;
    }

    return true;
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

    if (widget.isEditing) {
      final graduationConfirmed = await _confirmGraduationChange(
        academyId: currentUser.academyId,
        studentId: widget.student!.id,
      );

      if (!graduationConfirmed) {
        return;
      }

      if (!mounted) {
        return;
      }
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
          guardianIds: selectedGuardianIds.toList(growable: false),
          status: status,
          updatedBy: currentUser.id,
        );

        await _saveGraduationProgress(
          studentId: widget.student!.id,
          academyId: currentUser.academyId,
          approvedBy: currentUser.id,
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
          guardianIds: selectedGuardianIds.toList(growable: false),
          status: status,
          createdBy: currentUser.id,
        );
        await _saveGraduationProgress(
          studentId: studentId,
          academyId: currentUser.academyId,
          approvedBy: currentUser.id,
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
                    title: 'Responsáveis',
                    subtitle:
                        'Selecione uma ou mais contas responsáveis por este aluno.',
                  ),

                  const SizedBox(height: 14),

                  if (guardianUsers.isEmpty)
                    const Text(
                      'Nenhuma conta de responsável ativa cadastrada.',
                      style: TextStyle(color: AppColors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: guardianUsers.map((member) {
                        final selected = selectedGuardianIds.contains(
                          member.userId,
                        );

                        return FilterChip(
                          avatar: const Icon(Icons.family_restroom, size: 18),
                          label: Text(member.displayName),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                selectedGuardianIds.add(member.userId);
                              } else {
                                selectedGuardianIds.remove(member.userId);
                              }
                            });
                          },
                        );
                      }).toList(),
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
