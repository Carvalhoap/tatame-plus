import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/billing_cycle.dart';
import '../models/finance_period.dart';
import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_summary.dart';
import '../models/payment_proof.dart';
import '../repository/finance_repository.dart';
import '../services/finance_calculator.dart';
import 'financial_profiles_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  late FinancePeriod period;
  Future<_FinanceDashboardData>? dataFuture;

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

  Future<_FinanceDashboardData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final repository = context.read<FinanceRepository>();

    final results = await Future.wait<Object>([
      repository.getSettings(academyId: currentUser.academyId),
      repository.getBillingCycles(
        academyId: currentUser.academyId,
        period: period,
      ),
      repository.getPaymentProofs(
        academyId: currentUser.academyId,
        period: period,
      ),
      repository.getFinancialEntries(
        academyId: currentUser.academyId,
        period: period,
      ),
    ]);

    final settings = results[0] as FinanceSettings;
    final billingCycles = results[1] as List<BillingCycle>;
    final paymentProofs = results[2] as List<PaymentProof>;
    final entries = results[3] as List<FinancialEntry>;

    final summary = FinanceCalculator.calculate(
      period: period,
      settings: settings,
      billingCycles: billingCycles,
      paymentProofs: paymentProofs,
      entries: entries,
    );

    return _FinanceDashboardData(settings: settings, summary: summary);
  }

  Future<void> _reload() async {
    final nextFuture = _loadData();

    setState(() {
      dataFuture = nextFuture;
    });

    await nextFuture;
  }

  void _movePeriod(int months) {
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

  Future<void> _openFinancialProfiles() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const FinancialProfilesScreen()),
    );

    if (!mounted) {
      return;
    }

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financeiro'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_FinanceDashboardData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _reload);
          }

          final data = snapshot.data;

          if (data == null) {
            return _ErrorState(
              error: StateError('Os dados financeiros não foram carregados.'),
              onRetry: _reload,
            );
          }

          final summary = data.summary;
          final settings = data.settings;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _PeriodSelector(
                  period: period,
                  onPrevious: () => _movePeriod(-1),
                  onNext: () => _movePeriod(1),
                ),
                const SizedBox(height: 18),
                Card(
                  color: AppColors.white,
                  child: ListTile(
                    onTap: _openFinancialProfiles,
                    leading: const Icon(
                      Icons.manage_accounts_outlined,
                      color: AppColors.brandPrimary,
                    ),
                    title: const Text(
                      'Alunos e mensalidades',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Configure modalidade, valor e vencimento.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 18),
                if (summary.pendingProofsCount > 0) ...[
                  _PendingProofsAlert(count: summary.pendingProofsCount),
                  const SizedBox(height: 18),
                ],
                _MetricGrid(summary: summary),
                const SizedBox(height: 22),
                _BreakdownCard(
                  title: 'Composição da receita',
                  icon: Icons.trending_up,
                  rows: [
                    _AmountData(
                      'Mensalidades recebidas',
                      summary.monthlyFeeRevenueCents,
                    ),
                    _AmountData(
                      'Gympass aprovado',
                      summary.gympassRevenueCents,
                    ),
                    _AmountData('Outras receitas', summary.otherIncomeCents),
                    _AmountData(
                      'Receita bruta',
                      summary.grossRevenueCents,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BreakdownCard(
                  title: 'Destinação e fechamento',
                  icon: Icons.account_balance,
                  rows: [
                    _AmountData(
                      'Moving Fitness '
                      '(${settings.movingFitnessPercentage}%)',
                      summary.movingFitnessShareCents,
                    ),
                    _AmountData('Parte da academia', summary.academyShareCents),
                    _AmountData(
                      settings.instructorName,
                      summary.instructorCostCents,
                    ),
                    _AmountData('Outras despesas', summary.otherExpensesCents),
                    _AmountData(
                      'Reserva Gracie Barra '
                      '(${settings.gracieBarraReservePercentage}%)',
                      summary.gracieBarraReserveCents,
                    ),
                    _AmountData('Total dos sócios', summary.partnersTotalCents),
                    _AmountData(
                      'Valor por sócio '
                      '(${settings.remainingPartnersCount})',
                      summary.amountPerPartnerCents,
                      emphasized: true,
                    ),
                    if (summary.deficitCents > 0)
                      _AmountData(
                        'Déficit do período',
                        summary.deficitCents,
                        isNegative: true,
                        emphasized: true,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FinanceDashboardData {
  final FinanceSettings settings;
  final FinancialSummary summary;

  const _FinanceDashboardData({required this.settings, required this.summary});
}

class _PeriodSelector extends StatelessWidget {
  final FinancePeriod period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              tooltip: 'Período anterior',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onNext,
              tooltip: 'Próximo período',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingProofsAlert extends StatelessWidget {
  final int count;

  const _PendingProofsAlert({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count comprovante${count == 1 ? '' : 's'} '
              'aguardando análise.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final FinancialSummary summary;

  const _MetricGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: itemWidth,
              title: 'Receita bruta',
              amountCents: summary.grossRevenueCents,
              icon: Icons.payments_outlined,
            ),
            _MetricCard(
              width: itemWidth,
              title: 'Despesas',
              amountCents: summary.otherExpensesCents,
              icon: Icons.receipt_long_outlined,
            ),
            _MetricCard(
              width: itemWidth,
              title: 'Reserva GB',
              amountCents: summary.gracieBarraReserveCents,
              icon: Icons.savings_outlined,
            ),
            _MetricCard(
              width: itemWidth,
              title: 'Por sócio',
              amountCents: summary.amountPerPartnerCents,
              icon: Icons.handshake_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final int amountCents;
  final IconData icon;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.amountCents,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.brandPrimary),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: AppColors.grey)),
              const SizedBox(height: 4),
              Text(
                _currency(amountCents),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_AmountData> rows;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.brandPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            for (var index = 0; index < rows.length; index++) ...[
              _AmountRow(data: rows[index]),
              if (index < rows.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountData {
  final String label;
  final int amountCents;
  final bool emphasized;
  final bool isNegative;

  const _AmountData(
    this.label,
    this.amountCents, {
    this.emphasized = false,
    this.isNegative = false,
  });
}

class _AmountRow extends StatelessWidget {
  final _AmountData data;

  const _AmountRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isNegative
        ? AppColors.gracieRed
        : data.emphasized
        ? AppColors.brandPrimary
        : Colors.black87;

    return Row(
      children: [
        Expanded(
          child: Text(
            data.label,
            style: TextStyle(
              fontWeight: data.emphasized ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _currency(data.amountCents),
          style: TextStyle(
            fontWeight: data.emphasized ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
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
              'Não foi possível carregar o Financeiro.',
              textAlign: TextAlign.center,
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

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _currency(int cents) {
  final absoluteCents = cents.abs();
  final wholeValue = absoluteCents ~/ 100;
  final decimalValue = (absoluteCents % 100).toString().padLeft(2, '0');
  final wholeText = wholeValue.toString();
  final groups = <String>[];

  for (var end = wholeText.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, wholeText.substring(start, end));
  }

  final sign = cents < 0 ? '-' : '';

  return '${sign}R\$ ${groups.join('.')}'
      ',$decimalValue';
}
