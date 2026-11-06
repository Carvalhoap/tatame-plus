import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/document_assignment.dart';

const healthConsentText =
    'Consinto expressamente com o tratamento das informações de saúde '
    'fornecidas para adaptação segura das atividades e apoio em emergências. '
    'O acesso será limitado às pessoas que necessitem dessas informações '
    'para essas finalidades e, quando necessário ao atendimento, aos '
    'profissionais responsáveis pela emergência.';

class HealthEmergencyFormScreen extends StatefulWidget {
  final DocumentAssignment assignment;
  final Map<String, dynamic>? initialData;

  const HealthEmergencyFormScreen({
    super.key,
    required this.assignment,
    this.initialData,
  });

  @override
  State<HealthEmergencyFormScreen> createState() =>
      _HealthEmergencyFormScreenState();
}

class _HealthEmergencyFormScreenState extends State<HealthEmergencyFormScreen> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late Future<Student?> studentFuture;
  bool consent = false;
  String? allergiesStatus;
  String? restrictionsStatus;
  String studentName = '';
  String signerName = '';

  @override
  void initState() {
    super.initState();
    for (final key in [
      'birthDate',
      'phone',
      'email',
      'emergencyName',
      'emergencyPhone',
      'emergencyRelationship',
      'allergiesDetails',
      'restrictionsDetails',
      'notes',
    ]) {
      fields[key] = TextEditingController();
    }
    studentFuture = _load();
  }

  Future<Student?> _load() async {
    final repository = context.read<StudentRepository>();
    final user = context.read<SessionService>().currentUser;
    final student = await repository.getStudentById(
      academyId: widget.assignment.academyId,
      studentId: widget.assignment.studentId,
    );
    if (!mounted) {
      return student;
    }
    if (student == null || user == null) {
      throw StateError('Não foi possível carregar o aluno ou a sessão.');
    }
    studentName = student.fullName;
    signerName = user.name;
    final birth = student.birthDate;
    fields['birthDate']!.text = birth == null
        ? ''
        : '${birth.day.toString().padLeft(2, '0')}/'
              '${birth.month.toString().padLeft(2, '0')}/${birth.year}';
    fields['phone']!.text = student.phone ?? '';
    fields['email']!.text = student.email ?? '';
    final initial = widget.initialData;
    if (initial != null) {
      for (final entry in fields.entries) {
        entry.value.text = initial[entry.key] as String? ?? entry.value.text;
      }
      allergiesStatus = initial['allergiesStatus'] as String?;
      restrictionsStatus = initial['restrictionsStatus'] as String?;
    }
    return student;
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateBirth(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) {
      return 'Use dia/mês/ano.';
    }
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    if (date.day != day ||
        date.month != month ||
        date.year != year ||
        year < 1900 ||
        date.isAfter(DateTime.now())) {
      return 'Informe uma data de nascimento válida.';
    }
    return null;
  }

  Widget _field(
    String key,
    String label, {
    bool isRequired = false,
    int maxLength = 150,
    bool multiline = false,
    bool phone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: fields[key],
        maxLength: maxLength,
        minLines: multiline ? 2 : 1,
        maxLines: multiline ? 4 : 1,
        keyboardType: phone
            ? TextInputType.phone
            : (multiline ? TextInputType.multiline : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() => consent = false),
        validator: (raw) {
          final value = (raw ?? '').trim();
          if (isRequired && value.isEmpty) {
            return 'Preencha este campo.';
          }
          if (value.isEmpty) {
            return null;
          }
          if (key == 'birthDate') {
            return _validateBirth(value);
          }
          if (phone &&
              !RegExp(
                r'^\d{8,15}$',
              ).hasMatch(value.replaceAll(RegExp(r'\D'), ''))) {
            return 'Informe o telefone com DDD.';
          }
          if (key == 'email' &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
            return 'Informe um e-mail válido.';
          }
          return null;
        },
      ),
    );
  }

  Widget _status(String title, String? value, ValueChanged<String?> change) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: 'noneKnown',
            child: Text('Nenhuma conhecida'),
          ),
          DropdownMenuItem(
            value: 'hasDetails',
            child: Text('Tenho informações'),
          ),
          DropdownMenuItem(value: 'unknown', child: Text('Não sei informar')),
        ],
        onChanged: (selected) => setState(() {
          consent = false;
          change(selected);
        }),
        validator: (selected) =>
            selected == null ? 'Escolha uma resposta.' : null,
      ),
    );
  }

  void _continue() {
    if (!(formKey.currentState?.validate() ?? false) || !consent) {
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      for (final entry in fields.entries)
        if (entry.key != 'allergiesDetails' &&
            entry.key != 'restrictionsDetails')
          entry.key: entry.value.text.trim(),
      'allergiesStatus': allergiesStatus,
      'restrictionsStatus': restrictionsStatus,
      'allergiesDetails': allergiesStatus == 'hasDetails'
          ? fields['allergiesDetails']!.text.trim()
          : '',
      'restrictionsDetails': restrictionsStatus == 'hasDetails'
          ? fields['restrictionsDetails']!.text.trim()
          : '',
      'consent': true,
      'confirmed': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saúde e emergência')),
      body: FutureBuilder<Student?>(
        future: studentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Não foi possível carregar o cadastro do aluno.',
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        studentFuture = _load();
                      }),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Aluno: $studentName'),
                Text('Assinante: $signerName'),
                const SizedBox(height: 12),
                const Text(
                  'Confira os dados do cadastro e complete o formulário. '
                  'As informações serão incluídas no PDF desta assinatura. '
                  'O cadastro do aluno não será alterado.',
                ),
                const SizedBox(height: 20),
                _field(
                  'birthDate',
                  'Nascimento (dia/mês/ano)',
                  isRequired: true,
                  maxLength: 10,
                ),
                _field(
                  'phone',
                  'Telefone do aluno (opcional)',
                  phone: true,
                  maxLength: 30,
                ),
                _field('email', 'E-mail do aluno (opcional)', maxLength: 254),
                const Text(
                  'Contato de emergência',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _field('emergencyName', 'Nome do contato', isRequired: true),
                _field(
                  'emergencyPhone',
                  'Telefone com DDD',
                  isRequired: true,
                  phone: true,
                  maxLength: 30,
                ),
                _field(
                  'emergencyRelationship',
                  'Vínculo com o aluno',
                  isRequired: true,
                  maxLength: 80,
                ),
                _status(
                  'Alergias relevantes',
                  allergiesStatus,
                  (value) => allergiesStatus = value,
                ),
                if (allergiesStatus == 'hasDetails')
                  _field(
                    'allergiesDetails',
                    'Descreva as alergias relevantes',
                    isRequired: true,
                    multiline: true,
                    maxLength: 1000,
                  ),
                _status(
                  'Restrições ou recomendações para o treino',
                  restrictionsStatus,
                  (value) => restrictionsStatus = value,
                ),
                if (restrictionsStatus == 'hasDetails')
                  _field(
                    'restrictionsDetails',
                    'Descreva as restrições',
                    isRequired: true,
                    multiline: true,
                    maxLength: 1000,
                  ),
                _field(
                  'notes',
                  'Outras informações para emergência (opcional)',
                  multiline: true,
                  maxLength: 1000,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consent,
                  onChanged: (value) => setState(() => consent = value == true),
                  title: const Text(healthConsentText),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Text(
                  'O consentimento não vem marcado. Se não quiser '
                  'fornecer essas informações, volte e procure a administração '
                  'para combinar o atendimento. Este formulário não substitui '
                  'avaliação médica.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: consent ? _continue : null,
                  child: const Text('Conferi os dados e quero continuar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
