import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/check_in_provider.dart';
import '../repository/finance_repository.dart';

class CheckInProviderFormScreen extends StatefulWidget {
  final CheckInProvider? provider;

  const CheckInProviderFormScreen({super.key, this.provider});

  @override
  State<CheckInProviderFormScreen> createState() =>
      _CheckInProviderFormScreenState();
}

class _CheckInProviderFormScreenState extends State<CheckInProviderFormScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController valueController;
  late final TextEditingController limitController;

  late bool sharesWithMoving;
  late bool isActive;
  bool isSaving = false;

  bool get isEditing => widget.provider != null;

  @override
  void initState() {
    super.initState();

    final provider = widget.provider;

    nameController = TextEditingController(text: provider?.name ?? '');
    valueController = TextEditingController(
      text: provider == null ? '' : _currencyInput(provider.checkInValueCents),
    );
    limitController = TextEditingController(
      text: provider?.monthlyLimit.toString() ?? '12',
    );

    sharesWithMoving = provider?.sharesWithMoving ?? true;
    isActive = provider?.isActive ?? true;
  }

  @override
  void dispose() {
    nameController.dispose();
    valueController.dispose();
    limitController.dispose();
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

    final provider = CheckInProvider(
      id: widget.provider?.id ?? '',
      academyId: currentUser.academyId,
      name: nameController.text.trim(),
      checkInValueCents: _currencyToCents(valueController.text),
      monthlyLimit: int.parse(limitController.text),
      sharesWithMoving: sharesWithMoving,
      isActive: isActive,
      updatedAt: widget.provider?.updatedAt,
      updatedBy: currentUser.id,
    );

    setState(() {
      isSaving = true;
    });

    try {
      await repository.saveCheckInProvider(
        provider: provider,
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
        SnackBar(content: Text('Não foi possível salvar o convênio: $error')),
      );
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obrigatório.';
    }

    return null;
  }

  String? _positiveInteger(String? value) {
    final requiredError = _requiredText(value);

    if (requiredError != null) {
      return requiredError;
    }

    final parsed = int.tryParse(value!.trim());

    if (parsed == null || parsed < 1) {
      return 'Informe um número maior que zero.';
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
        title: Text(isEditing ? 'Editar convênio' : 'Novo convênio'),
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
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do convênio',
                        hintText: 'Ex.: Gympass ou TotalPass',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: valueController,
                      decoration: const InputDecoration(
                        labelText: 'Valor recebido por check-in',
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: limitController,
                      decoration: const InputDecoration(
                        labelText: 'Limite de check-ins por aluno',
                        helperText: 'Limite aplicado em cada período.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _positiveInteger,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: sharesWithMoving,
                      onChanged: (value) {
                        setState(() {
                          sharesWithMoving = value;
                        });
                      },
                      title: const Text('Compartilhar com a Moving'),
                      subtitle: const Text(
                        'Quando ativo, o valor entra na base da divisão.',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) {
                        setState(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Convênio ativo'),
                      subtitle: const Text(
                        'Convênios desativados mantêm o histórico.',
                      ),
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
                label: Text(isSaving ? 'Salvando...' : 'Salvar convênio'),
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
