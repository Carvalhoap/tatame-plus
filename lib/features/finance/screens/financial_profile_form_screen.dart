import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../models/check_in_provider.dart';
import '../models/finance_enums.dart';
import '../models/financial_profile.dart';
import '../repository/finance_repository.dart';

class FinancialProfileFormScreen extends StatefulWidget {
  final Student student;
  final FinancialProfile? profile;

  const FinancialProfileFormScreen({
    super.key,
    required this.student,
    required this.profile,
  });

  @override
  State<FinancialProfileFormScreen> createState() =>
      _FinancialProfileFormScreenState();
}

class _FinancialProfileFormScreenState
    extends State<FinancialProfileFormScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController monthlyFeeController;
  late final TextEditingController dueDayController;

  late BillingMode billingMode;
  late bool isActive;

  final List<CheckInProvider> checkInProviders = [];

  String? selectedCheckInProviderId;
  String? providerErrorMessage;

  bool providersLoadStarted = false;
  bool isLoadingProviders = true;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    final profile = widget.profile;
    final suggestedDueDay = widget.student.academyJoinDate?.day ?? 1;

    billingMode = profile?.billingMode ?? BillingMode.monthlyFee;
    selectedCheckInProviderId = profile?.effectiveCheckInProviderId;
    isActive = profile?.isActive ?? widget.student.isActive;

    monthlyFeeController = TextEditingController(
      text: profile == null
          ? ''
          : _formatEditableCurrency(profile.monthlyFeeCents),
    );

    dueDayController = TextEditingController(
      text: (profile?.dueDay ?? suggestedDueDay).toString(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!providersLoadStarted) {
      providersLoadStarted = true;
      _loadCheckInProviders();
    }
  }

  @override
  void dispose() {
    monthlyFeeController.dispose();
    dueDayController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckInProviders() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          isLoadingProviders = false;
          providerErrorMessage = 'Sua sessão não está disponível.';
        });
      }

      return;
    }

    final repository = context.read<FinanceRepository>();

    try {
      final loadedProviders = await repository.getCheckInProviders(
        academyId: currentUser.academyId,
      );

      if (!mounted) {
        return;
      }

      String? nextProviderId = selectedCheckInProviderId;

      final currentProviderExists = loadedProviders.any(
        (provider) => provider.id == nextProviderId,
      );

      if (!currentProviderExists) {
        nextProviderId = _firstActiveProviderId(loadedProviders);
      }

      setState(() {
        checkInProviders
          ..clear()
          ..addAll(loadedProviders);

        selectedCheckInProviderId = nextProviderId;
        isLoadingProviders = false;
        providerErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingProviders = false;
        providerErrorMessage = 'Não foi possível carregar os convênios: $error';
      });
    }
  }

  String? _firstActiveProviderId(Iterable<CheckInProvider> providers) {
    for (final provider in providers) {
      if (provider.isActive) {
        return provider.id;
      }
    }

    return null;
  }

  CheckInProvider? _providerById(String? providerId) {
    if (providerId == null || providerId.isEmpty) {
      return null;
    }

    for (final provider in checkInProviders) {
      if (provider.id == providerId) {
        return provider;
      }
    }

    return null;
  }

  Future<void> save() async {
    if (isSaving || !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final selectedProvider = _providerById(selectedCheckInProviderId);

    if (billingMode == BillingMode.gympass &&
        (selectedProvider == null || !selectedProvider.isActive)) {
      setState(() {
        errorMessage = 'Selecione um convênio de check-in ativo.';
      });

      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        errorMessage = 'Sua sessão não está disponível.';
      });

      return;
    }

    final monthlyFeeCents =
        _parseCurrencyToCents(monthlyFeeController.text) ?? 0;

    final dueDay = int.parse(dueDayController.text.trim());

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await context.read<FinanceRepository>().saveFinancialProfile(
        profile: FinancialProfile(
          academyId: currentUser.academyId,
          studentId: widget.student.id,
          billingMode: billingMode,
          checkInProviderId: billingMode == BillingMode.gympass
              ? selectedProvider!.id
              : null,
          monthlyFeeCents: monthlyFeeCents,
          dueDay: dueDay,
          isActive: isActive,
          updatedAt: widget.profile?.updatedAt,
          updatedBy: currentUser.id,
        ),
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
        errorMessage = 'Não foi possível salvar: $error';
      });
    }
  }

  Widget _checkInProviderField() {
    if (isLoadingProviders) {
      return const Card(
        color: AppColors.white,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(child: Text('Carregando convênios de check-in...')),
            ],
          ),
        ),
      );
    }

    if (providerErrorMessage != null) {
      return Card(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                providerErrorMessage!,
                style: const TextStyle(color: AppColors.gracieRed),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    isLoadingProviders = true;
                    providerErrorMessage = null;
                  });

                  _loadCheckInProviders();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final selectedProvider = _providerById(selectedCheckInProviderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedCheckInProviderId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Convênio de check-in',
            prefixIcon: Icon(Icons.qr_code_scanner_outlined),
            border: OutlineInputBorder(),
          ),
          items: checkInProviders
              .map(
                (provider) => DropdownMenuItem<String>(
                  value: provider.id,
                  enabled: provider.isActive,
                  child: Text(
                    provider.isActive
                        ? provider.name
                        : '${provider.name} (inativo)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: isSaving
              ? null
              : (value) {
                  setState(() {
                    selectedCheckInProviderId = value;
                  });
                },
          validator: (value) {
            if (billingMode != BillingMode.gympass) {
              return null;
            }

            final provider = _providerById(value);

            if (provider == null || !provider.isActive) {
              return 'Selecione um convênio ativo.';
            }

            return null;
          },
        ),
        if (selectedProvider != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${selectedProvider.name}: '
              '${_currency(selectedProvider.checkInValueCents)} por check-in, '
              'limite de ${selectedProvider.monthlyLimit} por período. '
              '${selectedProvider.sharesWithMoving ? 'Participa' : 'Não participa'} '
              'da divisão com a Moving.',
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitingForProviders =
        billingMode == BillingMode.gympass && isLoadingProviders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuração financeira'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Card(
                color: AppColors.white,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.white,
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    widget.student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    widget.student.isActive ? 'Aluno ativo' : 'Aluno inativo',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<BillingMode>(
                initialValue: billingMode,
                decoration: const InputDecoration(
                  labelText: 'Modalidade de cobrança',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(),
                ),
                items: BillingMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(_billingModeLabel(mode)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          billingMode = value;

                          if (value == BillingMode.gympass &&
                              selectedCheckInProviderId == null) {
                            selectedCheckInProviderId = _firstActiveProviderId(
                              checkInProviders,
                            );
                          }
                        });
                      },
              ),
              const SizedBox(height: 16),
              if (billingMode == BillingMode.monthlyFee)
                TextFormField(
                  controller: monthlyFeeController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor mensal',
                    hintText: 'Exemplo: 150,00',
                    prefixText: 'R\$ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final cents = _parseCurrencyToCents(value ?? '');

                    if (cents == null || cents <= 0) {
                      return 'Informe um valor de mensalidade válido.';
                    }

                    return null;
                  },
                )
              else if (billingMode == BillingMode.gympass)
                _checkInProviderField()
              else
                const _ExemptInformation(),
              const SizedBox(height: 16),
              TextFormField(
                controller: dueDayController,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dia do vencimento',
                  helperText: 'Por padrão, utilize o mesmo dia da matrícula.',
                  prefixIcon: Icon(Icons.event_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final day = int.tryParse(value?.trim() ?? '');

                  if (day == null || day < 1 || day > 31) {
                    return 'Informe um dia entre 1 e 31.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                color: AppColors.white,
                child: SwitchListTile(
                  value: isActive,
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            isActive = value;
                          });
                        },
                  title: const Text('Perfil financeiro ativo'),
                  subtitle: const Text(
                    'Desative para interromper novas cobranças.',
                  ),
                  secondary: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: AppColors.gracieRed),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving || waitingForProviders ? null : save,
                  icon: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Salvando...' : 'Salvar configuração'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExemptInformation extends StatelessWidget {
  const _ExemptInformation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.money_off_outlined, color: AppColors.brandPrimary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Este aluno não terá cobrança durante o período '
              'em que estiver isento.',
            ),
          ),
        ],
      ),
    );
  }
}

String _billingModeLabel(BillingMode mode) {
  switch (mode) {
    case BillingMode.monthlyFee:
      return 'Mensalidade';
    case BillingMode.gympass:
      return 'Convênio de check-in';
    case BillingMode.exempt:
      return 'Isento';
  }
}

String _currency(int cents) {
  return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
}

String _formatEditableCurrency(int cents) {
  return (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
}

int? _parseCurrencyToCents(String value) {
  var normalized = value.trim().replaceAll('R\$', '').replaceAll(' ', '');

  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  }

  final parsed = double.tryParse(normalized);

  if (parsed == null || !parsed.isFinite) {
    return null;
  }

  return (parsed * 100).round();
}
