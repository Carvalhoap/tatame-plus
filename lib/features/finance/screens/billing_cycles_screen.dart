import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/billing_cycle.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/financial_profile.dart';
import '../models/payment_proof.dart';
import '../repository/finance_repository.dart';

class BillingCyclesScreen extends StatefulWidget {
  const BillingCyclesScreen({super.key});

  @override
  State<BillingCyclesScreen> createState() => _BillingCyclesScreenState();
}

class _BillingCyclesScreenState extends State<BillingCyclesScreen> {
  late FinancePeriod period;
  Future<_BillingScreenData>? dataFuture;

  bool isGenerating = false;
  String? payingCycleId;

  @override
  void initState() {
    super.initState();
    period = FinancePeriod.containing(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dataFuture ??= _loadData();
  }

  Future<_BillingScreenData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final financeRepository = context.read<FinanceRepository>();

    final results = await Future.wait<Object>([
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
      financeRepository.getFinancialProfiles(academyId: currentUser.academyId),
      financeRepository.getBillingCycles(
        academyId: currentUser.academyId,
        period: period,
      ),
      financeRepository.getPaymentProofs(
        academyId: currentUser.academyId,
        period: period,
        status: PaymentProofStatus.pending,
      ),
    ]);

    final students = results[0] as List<Student>;
    final profiles = results[1] as List<FinancialProfile>;
    final cycles = results[2] as List<BillingCycle>;
    final pendingProofs = results[3] as List<PaymentProof>;

    final studentsById = {for (final student in students) student.id: student};

    cycles.sort((first, second) {
      final firstName =
          studentsById[first.studentId]?.fullName ?? first.studentId;
      final secondName =
          studentsById[second.studentId]?.fullName ?? second.studentId;

      return firstName.toLowerCase().compareTo(secondName.toLowerCase());
    });

    final activeProfileStudentIds = profiles
        .where((profile) => profile.isActive)
        .map((profile) => profile.studentId)
        .toSet();

    final missingConfigurationCount = students
        .where(
          (student) =>
              student.isActive && !activeProfileStudentIds.contains(student.id),
        )
        .length;

    return _BillingScreenData(
      studentsById: studentsById,
      profiles: profiles,
      cycles: cycles,
      pendingBillingCycleIds: pendingProofs
          .map((proof) => proof.billingCycleId)
          .whereType<String>()
          .toSet(),
      missingConfigurationCount: missingConfigurationCount,
    );
  }

  Future<void> reload() async {
    final nextFuture = _loadData();

    setState(() {
      dataFuture = nextFuture;
    });

    await nextFuture;
  }

  void movePeriod(int months) {
    final nextStart = DateTime(
      period.referenceYear,
      period.referenceMonth + months,
      15,
    );

    setState(() {
      period = FinancePeriod.fromReference(
        year: nextStart.year,
        month: nextStart.month,
      );
      dataFuture = _loadData();
    });
  }

  Future<void> generateBillingCycles() async {
    if (isGenerating || dataFuture == null) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final repository = context.read<FinanceRepository>();

    setState(() {
      isGenerating = true;
    });

    try {
      final data = await dataFuture!;
      final eligibleProfiles = data.profiles
          .where((profile) {
            final student = data.studentsById[profile.studentId];

            return profile.isActive && student?.isActive == true;
          })
          .toList(growable: false);

      if (eligibleProfiles.isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum perfil financeiro ativo foi encontrado.'),
          ),
        );
        return;
      }

      for (final profile in eligibleProfiles) {
        await repository.getOrCreateBillingCycle(
          academyId: currentUser.academyId,
          studentId: profile.studentId,
          period: period,
          createdBy: currentUser.id,
        );
      }

      if (!mounted) {
        return;
      }

      await reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${eligibleProfiles.length} cobrança'
            '${eligibleProfiles.length == 1 ? '' : 's'} '
            'verificada${eligibleProfiles.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar as cobranças: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  Future<void> markCashPayment(BillingCycle cycle) async {
    if (payingCycleId != null) {
      return;
    }

    final amountCents = await showDialog<int>(
      context: context,
      builder: (_) => _CashPaymentDialog(
        initialAmountCents: cycle.outstandingAmountCents > 0
            ? cycle.outstandingAmountCents
            : cycle.expectedAmountCents,
      ),
    );

    if (amountCents == null || !mounted) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    setState(() {
      payingCycleId = cycle.id;
    });

    try {
      await context.read<FinanceRepository>().markBillingCyclePaid(
        academyId: currentUser.academyId,
        billingCycleId: cycle.id,
        amountCents: amountCents,
        paymentMethod: PaymentMethod.cash,
        paidBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      await reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento em dinheiro registrado.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível registrar o pagamento: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          payingCycleId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cobranças do período'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isGenerating ? null : reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_BillingScreenData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: reload);
          }

          final data = snapshot.data;

          if (data == null) {
            return _ErrorState(
              error: StateError('As cobranças não foram carregadas.'),
              onRetry: reload,
            );
          }

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _PeriodSelector(
                  period: period,
                  onPrevious: isGenerating ? null : () => movePeriod(-1),
                  onNext: isGenerating ? null : () => movePeriod(1),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isGenerating ? null : generateBillingCycles,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.playlist_add_check),
                    label: Text(
                      isGenerating
                          ? 'Gerando cobranças...'
                          : 'Gerar ou atualizar lista do período',
                    ),
                  ),
                ),
                if (data.missingConfigurationCount > 0) ...[
                  const SizedBox(height: 14),
                  _WarningCard(count: data.missingConfigurationCount),
                ],
                const SizedBox(height: 18),
                Text(
                  '${data.cycles.length} cobrança'
                  '${data.cycles.length == 1 ? '' : 's'} no período',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (data.cycles.isEmpty)
                  const _EmptyState()
                else
                  ...data.cycles.map((cycle) {
                    final studentName =
                        data.studentsById[cycle.studentId]?.fullName ??
                        cycle.studentId;

                    final hasPendingProof = data.pendingBillingCycleIds
                        .contains(cycle.id);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BillingCycleCard(
                        cycle: cycle,
                        studentName: studentName,
                        hasPendingProof: hasPendingProof,
                        isPaying: payingCycleId == cycle.id,
                        onMarkCash: () => markCashPayment(cycle),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BillingScreenData {
  final Map<String, Student> studentsById;
  final List<FinancialProfile> profiles;
  final List<BillingCycle> cycles;
  final Set<String> pendingBillingCycleIds;
  final int missingConfigurationCount;

  const _BillingScreenData({
    required this.studentsById,
    required this.profiles,
    required this.cycles,
    required this.pendingBillingCycleIds,
    required this.missingConfigurationCount,
  });
}

class _PeriodSelector extends StatelessWidget {
  final FinancePeriod period;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PeriodSelector({
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  const Text(
                    'Período financeiro',
                    style: TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_date(period.start)} até '
                    '${_date(period.displayEnd)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final int count;

  const _WarningCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count aluno${count == 1 ? '' : 's'} ativo'
              '${count == 1 ? '' : 's'} sem configuração financeira.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingCycleCard extends StatelessWidget {
  final BillingCycle cycle;
  final String studentName;
  final bool hasPendingProof;
  final bool isPaying;
  final VoidCallback onMarkCash;

  const _BillingCycleCard({
    required this.cycle,
    required this.studentName,
    required this.hasPendingProof,
    required this.isPaying,
    required this.onMarkCash,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(cycle.status);

    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    studentName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: hasPendingProof
                      ? 'Em análise'
                      : _statusLabel(cycle.status),
                  color: hasPendingProof ? Colors.orange : statusColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _billingModeLabel(cycle.billingMode),
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 5),
            if (cycle.billingMode == BillingMode.monthlyFee) ...[
              Text('Valor: ${_currency(cycle.expectedAmountCents)}'),
              Text('Vencimento: ${_date(cycle.dueDate)}'),
              if (cycle.paidAmountCents > 0)
                Text('Pago: ${_currency(cycle.paidAmountCents)}'),
            ] else if (cycle.billingMode == BillingMode.gympass)
              const Text('Receita calculada pelos check-ins aprovados.')
            else
              const Text('Aluno isento neste período.'),
            if (cycle.billingMode == BillingMode.monthlyFee &&
                !cycle.isPaid &&
                !hasPendingProof) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isPaying ? null : onMarkCash,
                  icon: isPaying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: const Text('Registrar pagamento em dinheiro'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CashPaymentDialog extends StatefulWidget {
  final int initialAmountCents;

  const _CashPaymentDialog({required this.initialAmountCents});

  @override
  State<_CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<_CashPaymentDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(
      text: (widget.initialAmountCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pagamento em dinheiro'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor recebido',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final cents = _parseCurrencyToCents(value ?? '');

            if (cents == null || cents <= 0) {
              return 'Informe um valor válido.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.pop(
              context,
              _parseCurrencyToCents(amountController.text),
            );
          },
          child: const Text('Confirmar pagamento'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: AppColors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma cobrança gerada',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use o botão acima para gerar as cobranças deste período.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 54,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 14),
            const Text(
              'Não foi possível carregar as cobranças.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
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

String _billingModeLabel(BillingMode mode) {
  switch (mode) {
    case BillingMode.monthlyFee:
      return 'Mensalidade';
    case BillingMode.gympass:
      return 'Gympass';
    case BillingMode.exempt:
      return 'Isento';
  }
}

String _statusLabel(BillingStatus status) {
  switch (status) {
    case BillingStatus.pending:
      return 'Pendente';
    case BillingStatus.underReview:
      return 'Em análise';
    case BillingStatus.paid:
      return 'Pago';
    case BillingStatus.overdue:
      return 'Vencido';
    case BillingStatus.waived:
      return 'Isento';
  }
}

Color _statusColor(BillingStatus status) {
  switch (status) {
    case BillingStatus.paid:
      return Colors.green;
    case BillingStatus.overdue:
      return AppColors.gracieRed;
    case BillingStatus.underReview:
      return Colors.orange;
    case BillingStatus.waived:
      return AppColors.grey;
    case BillingStatus.pending:
      return Colors.blue;
  }
}

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _currency(int cents) {
  return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
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
