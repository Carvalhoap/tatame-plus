import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/finance_settings.dart';
import '../repository/finance_repository.dart';
import 'check_in_providers_screen.dart';
import 'recurring_expenses_screen.dart';

class FinanceSettingsScreen extends StatefulWidget {
  const FinanceSettingsScreen({super.key});

  @override
  State<FinanceSettingsScreen> createState() => _FinanceSettingsScreenState();
}

class _FinanceSettingsScreenState extends State<FinanceSettingsScreen> {
  final formKey = GlobalKey<FormState>();

  final gympassValueController = TextEditingController();
  final gympassLimitController = TextEditingController();
  final movingPercentageController = TextEditingController();
  final instructorNameController = TextEditingController();
  final instructorAmountController = TextEditingController();
  final reservePercentageController = TextEditingController();
  final partnersCountController = TextEditingController();

  Future<FinanceSettings>? settingsFuture;
  FinanceSettings? loadedSettings;
  bool isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    settingsFuture ??= _loadSettings();
  }

  @override
  void dispose() {
    gympassValueController.dispose();
    gympassLimitController.dispose();
    movingPercentageController.dispose();
    instructorNameController.dispose();
    instructorAmountController.dispose();
    reservePercentageController.dispose();
    partnersCountController.dispose();
    super.dispose();
  }

  Future<FinanceSettings> _loadSettings() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final settings = await context.read<FinanceRepository>().getSettings(
      academyId: currentUser.academyId,
    );

    loadedSettings = settings;
    _fillControllers(settings);

    return settings;
  }

  void _fillControllers(FinanceSettings settings) {
    gympassValueController.text = _currencyInput(
      settings.gympassCheckInValueCents,
    );
    gympassLimitController.text = settings.gympassMonthlyLimit.toString();
    movingPercentageController.text = settings.movingFitnessPercentage
        .toString();
    instructorNameController.text = settings.instructorName;
    instructorAmountController.text = _currencyInput(
      settings.instructorFixedAmountCents,
    );
    reservePercentageController.text = settings.gracieBarraReservePercentage
        .toString();
    partnersCountController.text = settings.remainingPartnersCount.toString();
  }

  Future<void> _reload() async {
    final nextFuture = _loadSettings();

    setState(() {
      settingsFuture = nextFuture;
    });

    await nextFuture;
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

    final settings = FinanceSettings(
      academyId: currentUser.academyId,
      gympassCheckInValueCents: _currencyToCents(gympassValueController.text),
      gympassMonthlyLimit: int.parse(gympassLimitController.text),
      movingFitnessPercentage: int.parse(movingPercentageController.text),
      instructorName: instructorNameController.text.trim(),
      instructorFixedAmountCents: _currencyToCents(
        instructorAmountController.text,
      ),
      gracieBarraReservePercentage: int.parse(reservePercentageController.text),
      remainingPartnersCount: int.parse(partnersCountController.text),
      updatedAt: loadedSettings?.updatedAt,
      updatedBy: currentUser.id,
    );

    setState(() {
      isSaving = true;
    });

    try {
      await repository.saveSettings(
        settings: settings,
        updatedBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      loadedSettings = settings;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações financeiras salvas.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar as configurações: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
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

  String? _percentage(String? value) {
    final requiredError = _requiredText(value);

    if (requiredError != null) {
      return requiredError;
    }

    final parsed = int.tryParse(value!.trim());

    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'Informe um percentual entre 0 e 100.';
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

  Future<void> _openCheckInProviders() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CheckInProvidersScreen()),
    );
  }

  Future<void> _openRecurringExpenses() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const RecurringExpensesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações financeiras'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isSaving ? null : _reload,
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<FinanceSettings>(
        future: settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _SettingsError(error: snapshot.error, onRetry: _reload);
          }

          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              children: [
                const _InformationCard(),
                const SizedBox(height: 16),
                Card(
                  color: AppColors.white,
                  child: ListTile(
                    onTap: _openCheckInProviders,
                    leading: const Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.brandPrimary,
                    ),
                    title: const Text(
                      'Convênios de check-in',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Configure Gympass, TotalPass e outros convênios.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: AppColors.white,
                  child: ListTile(
                    onTap: _openRecurringExpenses,
                    leading: const Icon(
                      Icons.event_repeat,
                      color: AppColors.brandPrimary,
                    ),
                    title: const Text(
                      'Despesas fixas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Configure professores, aluguel e custos recorrentes.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'Gympass',
                  icon: Icons.qr_code_scanner_outlined,
                  children: [
                    TextFormField(
                      controller: gympassValueController,
                      decoration: const InputDecoration(
                        labelText: 'Valor por check-in',
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
                      controller: gympassLimitController,
                      decoration: const InputDecoration(
                        labelText: 'Limite de check-ins por aluno',
                        helperText: 'Limite considerado em cada período.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _positiveInteger,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'Divisão com a Moving',
                  icon: Icons.handshake_outlined,
                  children: [
                    TextFormField(
                      controller: movingPercentageController,
                      decoration: const InputDecoration(
                        labelText: 'Percentual da Moving',
                        suffixText: '%',
                        helperText:
                            'Aplicado somente às mensalidades '
                            'compartilhadas e ao Gympass.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _percentage,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'Professor',
                  icon: Icons.school_outlined,
                  children: [
                    TextFormField(
                      controller: instructorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do professor',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      validator: _requiredText,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: instructorAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Valor fixo do professor',
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
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  title: 'Reserva e sócios',
                  icon: Icons.account_balance_outlined,
                  children: [
                    TextFormField(
                      controller: reservePercentageController,
                      decoration: const InputDecoration(
                        labelText: 'Percentual da reserva Gracie Barra',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _percentage,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: partnersCountController,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de sócios',
                        helperText:
                            'Quantidade usada para dividir o valor final.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _positiveInteger,
                    ),
                  ],
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
                    label: Text(
                      isSaving ? 'Salvando...' : 'Salvar configurações',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
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
                'As alterações serão utilizadas nos próximos cálculos '
                'do painel e dos relatórios financeiros.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brandPrimary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _SettingsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar as configurações: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
