import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../../users/models/academy_member.dart';
import '../../users/repository/user_repository.dart';
import '../models/document_assignment.dart';
import '../models/document_enums.dart';
import '../models/legal_document.dart';
import '../repository/document_repository.dart';

class DocumentAssignmentsScreen extends StatefulWidget {
  const DocumentAssignmentsScreen({super.key});

  @override
  State<DocumentAssignmentsScreen> createState() =>
      _DocumentAssignmentsScreenState();
}

class _DocumentAssignmentsScreenState extends State<DocumentAssignmentsScreen> {
  late Future<_AssignmentData> dataFuture;

  final Set<String> selectedStudentIds = {};
  final Map<String, String> selectedSignerIds = {};

  String? selectedDocumentId;
  String searchText = '';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    dataFuture = _loadData();
  }

  Future<_AssignmentData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final results = await Future.wait<Object>([
      context.read<DocumentRepository>().getPublishedDocuments(
        academyId: currentUser.academyId,
      ),
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
      context.read<UserRepository>().getAcademyMembers(
        academyId: currentUser.academyId,
      ),
    ]);

    final now = DateTime.now();

    final documents =
        List<LegalDocument>.from(
          results[0] as List<LegalDocument>,
        ).where((document) => document.isEffectiveAt(now)).toList()..sort(
          (first, second) =>
              first.title.toLowerCase().compareTo(second.title.toLowerCase()),
        );

    final students =
        List<Student>.from(
          results[1] as List<Student>,
        ).where((student) => student.isActive).toList()..sort(
          (first, second) => first.fullName.toLowerCase().compareTo(
            second.fullName.toLowerCase(),
          ),
        );

    final members = List<AcademyMember>.from(results[2] as List<AcademyMember>);

    return _AssignmentData(
      documents: documents,
      students: students,
      membersById: {for (final member in members) member.userId: member},
    );
  }

  void _reload() {
    setState(() {
      selectedStudentIds.clear();
      selectedSignerIds.clear();
      selectedDocumentId = null;
      dataFuture = _loadData();
    });
  }

  int _ageAt(DateTime birthDate, DateTime referenceDate) {
    var age = referenceDate.year - birthDate.year;

    final birthdayOccurred =
        referenceDate.month > birthDate.month ||
        (referenceDate.month == birthDate.month &&
            referenceDate.day >= birthDate.day);

    if (!birthdayOccurred) {
      age--;
    }

    return age;
  }

  _StudentAssignmentPlan _planForStudent(
    Student student,
    _AssignmentData data,
  ) {
    final birthDate = student.birthDate;

    if (birthDate == null) {
      return const _StudentAssignmentPlan.blocked(
        reason: 'Cadastre a data de nascimento do aluno.',
      );
    }

    final age = _ageAt(birthDate, DateTime.now());
    final isMinor = age < 18;

    if (!isMinor) {
      final userId = student.userId?.trim() ?? '';

      if (userId.isEmpty) {
        return _StudentAssignmentPlan.blocked(
          age: age,
          reason: 'O aluno adulto ainda não possui acesso ao aplicativo.',
        );
      }

      final member = data.membersById[userId];

      if (member == null || !member.isActive || member.status != 'active') {
        return _StudentAssignmentPlan.blocked(
          age: age,
          reason: 'O acesso do aluno está ausente ou inativo.',
        );
      }

      return _StudentAssignmentPlan(
        age: age,
        role: DocumentSignerRole.student,
        signers: [
          _SignerOption(userId: member.userId, displayName: member.displayName),
        ],
      );
    }

    final guardians = <_SignerOption>[];

    for (final guardianId in student.guardianIds) {
      final member = data.membersById[guardianId];

      if (member == null ||
          !member.isActive ||
          member.status != 'active' ||
          !member.hasRole('guardian')) {
        continue;
      }

      guardians.add(
        _SignerOption(userId: member.userId, displayName: member.displayName),
      );
    }

    guardians.sort(
      (first, second) => first.displayName.toLowerCase().compareTo(
        second.displayName.toLowerCase(),
      ),
    );

    if (guardians.isEmpty) {
      return _StudentAssignmentPlan.blocked(
        age: age,
        reason: 'Nenhum responsável ativo está vinculado ao aluno.',
      );
    }

    return _StudentAssignmentPlan(
      age: age,
      role: DocumentSignerRole.guardian,
      signers: guardians,
    );
  }

  void _toggleStudent(
    Student student,
    _StudentAssignmentPlan plan,
    bool selected,
  ) {
    setState(() {
      if (!selected) {
        selectedStudentIds.remove(student.id);
        selectedSignerIds.remove(student.id);
        return;
      }

      selectedStudentIds.add(student.id);

      if (plan.signers.length == 1) {
        selectedSignerIds[student.id] = plan.signers.first.userId;
      } else {
        selectedSignerIds.remove(student.id);
      }
    });
  }

  Future<void> _saveAssignments(_AssignmentData data) async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final document = data.documents
        .where((item) => item.id == selectedDocumentId)
        .firstOrNull;

    if (document == null) {
      _showMessage('Selecione o documento que será atribuído.');
      return;
    }

    if (selectedStudentIds.isEmpty) {
      _showMessage('Selecione pelo menos um aluno.');
      return;
    }

    final selectedStudents = data.students
        .where((student) => selectedStudentIds.contains(student.id))
        .toList();

    for (final student in selectedStudents) {
      final plan = _planForStudent(student, data);

      if (!plan.canAssign) {
        _showMessage('${student.fullName}: ${plan.blockReason}');
        return;
      }

      if (!selectedSignerIds.containsKey(student.id)) {
        _showMessage('Escolha quem assinará por ${student.fullName}.');
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    var createdCount = 0;
    var duplicatedCount = 0;

    try {
      final repository = context.read<DocumentRepository>();

      for (final student in selectedStudents) {
        final existingAssignments = await repository.getAssignmentsForStudent(
          academyId: currentUser.academyId,
          studentId: student.id,
        );

        final alreadyAssigned = existingAssignments.any(
          (assignment) =>
              assignment.documentId == document.id &&
              assignment.documentVersion == document.version &&
              assignment.status != DocumentAssignmentStatus.expired,
        );

        if (alreadyAssigned) {
          duplicatedCount++;
          continue;
        }

        final plan = _planForStudent(student, data);

        final assignment = DocumentAssignment(
          id: repository.createAssignmentId(academyId: currentUser.academyId),
          academyId: currentUser.academyId,
          documentId: document.id,
          documentVersion: document.version,
          studentId: student.id,
          studentName: student.fullName,
          requiredSignerRole: plan.role!,
          assignedSignerUserId: selectedSignerIds[student.id],
          status: DocumentAssignmentStatus.pending,
          assignedAt: DateTime.now(),
          signedAt: null,
          expiresAt: document.expiresAt,
          assignedBy: currentUser.id,
        );

        await repository.saveAssignment(assignment: assignment);

        createdCount++;
      }

      if (!mounted) {
        return;
      }

      selectedStudentIds.clear();
      selectedSignerIds.clear();

      var message = '$createdCount atribuição(ões) criada(s) com sucesso.';

      if (duplicatedCount > 0) {
        message +=
            ' $duplicatedCount já existia(m) e não foi(ram) duplicada(s).';
      }

      _showMessage(message, success: true);

      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível concluir as atribuições: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Atribuir documentos'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: isSaving ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_AssignmentData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data!;

          if (data.documents.isEmpty) {
            return const _EmptyState(
              icon: Icons.description_outlined,
              title: 'Nenhum documento disponível',
              message:
                  'Publique um documento válido antes de fazer atribuições.',
            );
          }

          selectedDocumentId ??= data.documents.first.id;

          final normalizedSearch = searchText.trim().toLowerCase();

          final visibleStudents = data.students.where((student) {
            if (normalizedSearch.isEmpty) {
              return true;
            }

            return student.fullName.toLowerCase().contains(normalizedSearch);
          }).toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: AppColors.white,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Documento',
                              style: TextStyle(
                                color: AppColors.brandPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedDocumentId,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Documento publicado',
                              ),
                              items: data.documents.map((document) {
                                return DropdownMenuItem(
                                  value: document.id,
                                  child: Text(
                                    '${document.title} • versão '
                                    '${document.version}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedDocumentId = value;
                                        selectedStudentIds.clear();
                                        selectedSignerIds.clear();
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar aluno',
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${selectedStudentIds.length} aluno(s) selecionado(s)',
                      style: const TextStyle(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleStudents.isEmpty)
                      const _EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'Nenhum aluno encontrado',
                        message: 'Altere a busca para localizar outro aluno.',
                      )
                    else
                      ...visibleStudents.map((student) {
                        final plan = _planForStudent(student, data);

                        final selected = selectedStudentIds.contains(
                          student.id,
                        );

                        return _StudentAssignmentCard(
                          student: student,
                          plan: plan,
                          selected: selected,
                          selectedSignerId: selectedSignerIds[student.id],
                          enabled: !isSaving,
                          onSelected: (value) {
                            _toggleStudent(student, plan, value);
                          },
                          onSignerSelected: (value) {
                            setState(() {
                              if (value == null) {
                                selectedSignerIds.remove(student.id);
                              } else {
                                selectedSignerIds[student.id] = value;
                              }
                            });
                          },
                        );
                      }),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: AppColors.white,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : () => _saveAssignments(data),
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.assignment_add),
                    label: Text(
                      isSaving
                          ? 'Criando atribuições...'
                          : 'Atribuir documento',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentAssignmentCard extends StatelessWidget {
  final Student student;
  final _StudentAssignmentPlan plan;
  final bool selected;
  final String? selectedSignerId;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String?> onSignerSelected;

  const _StudentAssignmentCard({
    required this.student,
    required this.plan,
    required this.selected,
    required this.selectedSignerId,
    required this.enabled,
    required this.onSelected,
    required this.onSignerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final canSelect = enabled && plan.canAssign;

    return Card(
      color: AppColors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
        child: Column(
          children: [
            CheckboxListTile(
              value: selected,
              onChanged: canSelect
                  ? (value) => onSelected(value == true)
                  : null,
              title: Text(
                student.fullName,
                style: const TextStyle(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(_subtitle()),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (!plan.canAssign)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  plan.blockReason!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            if (selected && plan.signers.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSignerId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Responsável que deverá assinar',
                  ),
                  items: plan.signers.map((signer) {
                    return DropdownMenuItem(
                      value: signer.userId,
                      child: Text(signer.displayName),
                    );
                  }).toList(),
                  onChanged: enabled ? onSignerSelected : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final ageText = plan.age == null
        ? 'Idade não informada'
        : '${plan.age} anos';

    if (!plan.canAssign) {
      return ageText;
    }

    if (plan.role == DocumentSignerRole.guardian) {
      return '$ageText • assinatura do responsável';
    }

    return '$ageText • assinatura do próprio aluno';
  }
}

class _AssignmentData {
  final List<LegalDocument> documents;
  final List<Student> students;
  final Map<String, AcademyMember> membersById;

  const _AssignmentData({
    required this.documents,
    required this.students,
    required this.membersById,
  });
}

class _StudentAssignmentPlan {
  final int? age;
  final DocumentSignerRole? role;
  final List<_SignerOption> signers;
  final String? blockReason;

  const _StudentAssignmentPlan({
    required this.age,
    required this.role,
    required this.signers,
  }) : blockReason = null;

  const _StudentAssignmentPlan.blocked({this.age, required String reason})
    : role = null,
      signers = const [],
      blockReason = reason;

  bool get canAssign {
    return role != null && signers.isNotEmpty && blockReason == null;
  }
}

class _SignerOption {
  final String userId;
  final String displayName;

  const _SignerOption({required this.userId, required this.displayName});
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível carregar os dados',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.grey),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
