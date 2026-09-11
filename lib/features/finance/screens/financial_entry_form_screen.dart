import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../repository/finance_repository.dart';

class FinancialEntryFormScreen extends StatefulWidget {
  final FinancePeriod period;

  const FinancialEntryFormScreen({super.key, required this.period});

  @override
  State<FinancialEntryFormScreen> createState() =>
      _FinancialEntryFormScreenState();
}

class _FinancialEntryFormScreenState extends State<FinancialEntryFormScreen> {
  static const incomeCategories = [
    'Graduação',
    'Faixa',
    'Certificado',
    'Produto',
    'Evento',
    'Outra receita',
  ];

  static const expenseCategories = [
    'Professor',
    'Aluguel',
    'Material',
    'Manutenção',
    'Taxa',
    'Imposto',
    'Outra despesa',
  ];

  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  final customCategoryController = TextEditingController();

  FinancialEntryType entryType = FinancialEntryType.income;
  PaymentMethod paymentMethod = PaymentMethod.pix;
  late String selectedCategory;
  late DateTime occurredAt;

  String? selectedStudentId;
  Future<List<Student>>? studentsFuture;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    selectedCategory = incomeCategories.first;

    final now = DateTime.now();

    occurredAt = widget.period.contains(now)
        ? DateTime(now.year, now.month, now.day)
        : widget.period.start;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    studentsFuture ??= _loadStudents();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    customCategoryController.dispose();
    super.dispose();
  }

  List<String> get availableCategories {
    return entryType == FinancialEntryType.income
        ? incomeCategories
        : expenseCategories;
  }

  bool get isCustomCategory {
    return selectedCategory == 'Outra receita' ||
        selectedCategory == 'Outra despesa';
  }

  Future<List<Student>> _loadStudents() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final students = await context
        .read<StudentRepository>()
        .getStudentsByAcademy(currentUser.academyId);

    final activeStudents = students
        .where((student) => student.isActive)
        .toList();

    activeStudents.sort(
      (first, second) =>
          first.fullName.toLowerCase().compareTo(second.fullName.toLowerCase()),
    );

    return activeStudents;
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: widget.period.start,
      lastDate: widget.period.displayEnd,
      helpText: 'Data do lançamento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      occurredAt = selectedDate;
    });
  }

  Future<void> _save() async {
    if (isSaving || !formKey.currentState!.validate()) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final amountCents = _parseAmountCents(amountController.text);

    if (amountCents == null || amountCents <= 0) {
      return;
    }

    final category = isCustomCategory
        ? customCategoryController.text.trim()
        : selectedCategory;

    setState(() {
      isSaving = true;
    });

    try {
      await context.read<FinanceRepository>().createFinancialEntry(
        academyId: currentUser.academyId,
        type: entryType,
        category: category,
        description: descriptionController.text.trim(),
        amountCents: amountCents,
        occurredAt: occurredAt,
        createdBy: currentUser.id,
        studentId: selectedStudentId,
        paymentMethod: paymentMethod,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o lançamento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  int? _parseAmountCents(String value) {
    var normalized = value.trim().replaceAll('R\$', '').replaceAll(' ', '');

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    final amount = double.tryParse(normalized);

    if (amount == null) {
      return null;
    }

    return (amount * 100).round();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.pix:
        return 'Pix';
      case PaymentMethod.cash:
        return 'Dinheiro';
      case PaymentMethod.card:
        return 'Cartão';
      case PaymentMethod.bankTransfer:
        return 'Transferência bancária';
      case PaymentMethod.other:
        return 'Outro';
      case PaymentMethod.gympass:
        return 'Gympass';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = entryType == FinancialEntryType.income;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Novo lançamento'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<FinancialEntryType>(
              initialValue: entryType,
              decoration: const InputDecoration(
                labelText: 'Tipo de lançamento',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: FinancialEntryType.income,
                  child: Text('Receita'),
                ),
                DropdownMenuItem(
                  value: FinancialEntryType.expense,
                  child: Text('Despesa'),
                ),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        entryType = value;
                        selectedCategory = availableCategories.first;
                        customCategoryController.clear();
                      });
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(entryType),
              initialValue: selectedCategory,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: availableCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedCategory = value;
                      });
                    },
            ),
            if (isCustomCategory) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: customCategoryController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: isIncome
                      ? 'Nome da outra receita'
                      : 'Nome da outra despesa',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome da categoria.';
                  }

                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              enabled: !isSaving,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Descreva o motivo do lançamento',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a descrição.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              enabled: !isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                hintText: '0,00',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amountCents = _parseAmountCents(value ?? '');

                if (amountCents == null || amountCents <= 0) {
                  return 'Informe um valor maior que zero.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: paymentMethod,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                border: OutlineInputBorder(),
              ),
              items: PaymentMethod.values
                  .where((method) => method != PaymentMethod.gympass)
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(_paymentMethodLabel(method)),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        paymentMethod = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Student>>(
              future: studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final students = snapshot.data ?? const <Student>[];

                return DropdownButtonFormField<String?>(
                  initialValue: selectedStudentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aluno relacionado',
                    helperText: 'Opcional',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Nenhum aluno'),
                    ),
                    ...students.map(
                      (student) => DropdownMenuItem<String?>(
                        value: student.id,
                        child: Text(
                          student.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            selectedStudentId = value;
                          });
                        },
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.white,
              child: ListTile(
                onTap: isSaving ? null : _selectDate,
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.brandPrimary,
                ),
                title: const Text('Data do lançamento'),
                subtitle: Text(_formatDate(occurredAt)),
                trailing: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _save,
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isIncome ? Icons.add_chart : Icons.trending_down),
                label: Text(isSaving ? 'Salvando...' : 'Salvar lançamento'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
