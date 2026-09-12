import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/recurring_expense.dart';
import '../repository/finance_repository.dart';

class RecurringExpenseFormScreen extends StatefulWidget {
  final RecurringExpense? expense;

  const RecurringExpenseFormScreen({super.key, this.expense});

  @override
  State<RecurringExpenseFormScreen> createState() =>
      _RecurringExpenseFormScreenState();
}

class _RecurringExpenseFormScreenState
    extends State<RecurringExpenseFormScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController categoryController;
  late final TextEditingController descriptionController;
  late final TextEditingController amountController;

  late bool isActive;
  bool isSaving = false;

  bool get isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    categoryController = TextEditingController(text: expense?.category ?? '');
    descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    amountController = TextEditingController(
      text: expense == null ? '' : _currencyInput(expense.amountCents),
    );

    isActive = expense?.isActive ?? true;
  }

  @override
  void dispose() {
    categoryController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (isSaving || !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final repository = context.read<FinanceRepository>();

    final expense = RecurringExpense(
      id: widget.expense?.id ?? '',
      academyId: currentUser.academyId,
      category: categoryController.text.trim(),
      description: descriptionController.text.trim(),
      amountCents: _currencyToCents(amountController.text),
      isActive: isActive,
      updatedAt: widget.expense?.updatedAt,
      updatedBy: currentUser.id,
    );

    setState(() {
      isSaving = true;
    });

    try {
      await repository.saveRecurringExpense(
        expense: expense,
        updatedBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar a despesa fixa: $error'),
        ),
      );
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  String? _money(String? value) {
    final requiredError = _requiredText(value);

    if (requiredError != null) {
      return requiredError;
    }

    try {
      if (_currencyToCents(value!) < 0) {
        return 'O valor não pode ser negativo.';
      }
    } catch (_) {
      return 'Informe um valor válido.';
    }

    return null;
  }

  int _currencyToCents(String value) {
    var normalized = value.trim().replaceAll('R\$', '').replaceAll(' ', '');

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    final parsed = double.tryParse(normalized);

    if (parsed == null) {
      throw const FormatException('Valor inválido.');
    }

    return (parsed * 100).round();
  }

  String _currencyInput(int cents) {
    return (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar despesa fixa' : 'Nova despesa fixa'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.brandPrimary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enquanto estiver ativa, esta despesa será descontada '
                        'automaticamente em todos os períodos financeiros.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        hintText: 'Ex.: Professores, aluguel ou sistema',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 100,
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Ex.: Professor Wagner',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 200,
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Valor por período',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: _money,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Despesa ativa'),
                      subtitle: const Text(
                        'Desative para interromper os próximos descontos '
                        'sem apagar o histórico.',
                      ),
                      value: isActive,
                      onChanged: (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                    ),
                  ],
                ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Salvando...' : 'Salvar despesa fixa'),
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
