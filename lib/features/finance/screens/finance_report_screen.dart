import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/billing_cycle.dart';
import '../models/check_in_provider.dart';
import '../models/finance_period.dart';
import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_summary.dart';
import '../models/payment_proof.dart';
import '../models/recurring_expense.dart';
import '../repository/finance_repository.dart';
import '../services/finance_calculator.dart';
import '../services/finance_report_pdf_service.dart';

class FinanceReportScreen extends StatefulWidget {
  const FinanceReportScreen({super.key});

  @override
  State<FinanceReportScreen> createState() => _FinanceReportScreenState();
}

class _FinanceReportScreenState extends State<FinanceReportScreen> {
  late FinancePeriod period;
  Future<_FinanceReportData>? dataFuture;
  bool isGeneratingPdf = false;

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

  Future<_FinanceReportData> _loadData() async {
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
      repository.getCheckInProviders(academyId: currentUser.academyId),
      repository.getRecurringExpenses(academyId: currentUser.academyId),
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
    ]);

    final settings = results[0] as FinanceSettings;
    final billingCycles = results[1] as List<BillingCycle>;
    final paymentProofs = results[2] as List<PaymentProof>;
    final entries = results[3] as List<FinancialEntry>;
    final checkInProviders = results[4] as List<CheckInProvider>;
    final recurringExpenses = results[5] as List<RecurringExpense>;
    final students = results[6] as List<Student>;

    final summary = FinanceCalculator.calculate(
      period: period,
      settings: settings,
      billingCycles: billingCycles,
      paymentProofs: paymentProofs,
      entries: entries,
      checkInProviders: checkInProviders,
      recurringExpenses: recurringExpenses,
    );

    return _FinanceReportData(
      settings: settings,
      summary: summary,
      recurringExpenses: recurringExpenses
          .where((expense) => expense.isActive)
          .toList(growable: false),
      entries: entries,
      studentNames: {
        for (final student in students) student.id: student.fullName,
      },
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

  Future<void> generatePdf() async {
    if (isGeneratingPdf || dataFuture == null) {
      return;
    }

    setState(() {
      isGeneratingPdf = true;
    });

    try {
      final data = await dataFuture!;

      final bytes = await FinanceReportPdfService.build(
        summary: data.summary,
        settings: data.settings,
        recurringExpenses: data.recurringExpenses,
        entries: data.entries,
        studentNames: data.studentNames,
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'fechamento-financeiro-${period.key}.pdf',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o relatório: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingPdf = false;
        });
      }
    }
  }

  Map<String, int> totalsByCategory(Iterable<FinancialEntry> entries) {
    final totals = <String, int>{};

    for (final entry in entries.where((item) => item.isActive)) {
      totals.update(
        entry.category,
        (value) => value + entry.amountCents,
        ifAbsent: () => entry.amountCents,
      );
    }

    return totals;
  }

  String formatCurrency(int amountCents) {
    final value = (amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');

    return 'R\$ $value';
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fechamento financeiro'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isGeneratingPdf ? null : generatePdf,
            tooltip: 'Gerar PDF',
            icon: isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            onPressed: reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodSelector(
            text:
                '${formatDate(period.start)} a '
                '${formatDate(period.displayEnd)}',
            onPrevious: () => movePeriod(-1),
            onNext: () => movePeriod(1),
          ),
          Expanded(
            child: FutureBuilder<_FinanceReportData>(
              future: dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error, onRetry: reload);
                }

                final data = snapshot.data!;
                final summary = data.summary;
                final settings = data.settings;
                final recurringExpenses = data.recurringExpenses;

                final incomeByCategory = totalsByCategory(
                  data.entries.where((entry) => entry.isIncome),
                );

                final expensesByCategory = totalsByCategory(
                  data.entries.where((entry) => entry.isExpense),
                );

                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                    children: [
                      if (summary.pendingProofsCount > 0) ...[
                        _PendingAlert(count: summary.pendingProofsCount),
                        const SizedBox(height: 16),
                      ],
                      _SectionCard(
                        title: 'Composição da receita',
                        icon: Icons.trending_up,
                        rows: [
                          _ReportRow(
                            label: 'Mensalidades compartilhadas com a Moving',
                            value: formatCurrency(
                              summary.sharedMonthlyFeeRevenueCents,
                            ),
                          ),
                          _ReportRow(
                            label: 'Mensalidades recebidas pela equipe',
                            value: formatCurrency(
                              summary.directMonthlyFeeRevenueCents,
                            ),
                          ),
                          _ReportRow(
                            label: 'Gympass compartilhado',
                            value: formatCurrency(summary.gympassRevenueCents),
                          ),
                          _ReportRow(
                            label: 'Outras receitas integrais da equipe',
                            value: formatCurrency(summary.otherIncomeCents),
                          ),
                          _ReportRow(
                            label: 'Base da divisão com a Moving',
                            value: formatCurrency(
                              summary.movingSharedRevenueBaseCents,
                            ),
                          ),
                          _ReportRow(
                            label: 'Receita bruta total',
                            value: formatCurrency(summary.grossRevenueCents),
                            isStrong: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Divisão e deduções',
                        icon: Icons.account_balance_outlined,
                        rows: [
                          _ReportRow(
                            label:
                                'Moving Fitness '
                                '(${settings.movingFitnessPercentage}% '
                                'somente da base compartilhada)',
                            value: formatCurrency(
                              summary.movingFitnessShareCents,
                            ),
                          ),
                          _ReportRow(
                            label: 'Total da equipe antes das despesas',
                            value: formatCurrency(summary.academyShareCents),
                            isStrong: true,
                          ),
                          ...recurringExpenses.map(
                            (expense) => _ReportRow(
                              label:
                                  '${expense.category}: '
                                  '${expense.description}',
                              value: formatCurrency(expense.amountCents),
                            ),
                          ),
                          _ReportRow(
                            label: 'Total das despesas fixas',
                            value: formatCurrency(summary.instructorCostCents),
                            isStrong: true,
                          ),
                          _ReportRow(
                            label: 'Outras despesas',
                            value: formatCurrency(summary.otherExpensesCents),
                          ),
                          _ReportRow(
                            label: 'Disponível após deduções',
                            value: formatCurrency(
                              summary.availableAfterDeductionsCents,
                            ),
                            isStrong: true,
                          ),
                          if (summary.hasDeficit)
                            _ReportRow(
                              label: 'Déficit',
                              value: formatCurrency(summary.deficitCents),
                              isStrong: true,
                              isWarning: true,
                            ),
                          _ReportRow(
                            label:
                                'Reserva Gracie Barra '
                                '(${settings.gracieBarraReservePercentage}%)',
                            value: formatCurrency(
                              summary.gracieBarraReserveCents,
                            ),
                          ),
                          _ReportRow(
                            label: 'Total dos sócios',
                            value: formatCurrency(summary.partnersTotalCents),
                          ),
                          _ReportRow(
                            label:
                                'Valor por sócio '
                                '(${settings.remainingPartnersCount})',
                            value: formatCurrency(
                              summary.amountPerPartnerCents,
                            ),
                            isStrong: true,
                          ),
                        ],
                      ),
                      if (incomeByCategory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CategoryCard(
                          title: 'Receitas por categoria',
                          totals: incomeByCategory,
                          color: Colors.green.shade700,
                          formatCurrency: formatCurrency,
                        ),
                      ],
                      if (expensesByCategory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CategoryCard(
                          title: 'Despesas por categoria',
                          totals: expensesByCategory,
                          color: Colors.red.shade700,
                          formatCurrency: formatCurrency,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _EntriesCard(
                        entries: data.entries,
                        studentNames: data.studentNames,
                        formatCurrency: formatCurrency,
                        formatDate: formatDate,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: isGeneratingPdf ? null : generatePdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                            isGeneratingPdf
                                ? 'Gerando relatório...'
                                : 'Gerar PDF do fechamento',
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
          ),
        ],
      ),
    );
  }
}

class _FinanceReportData {
  final FinanceSettings settings;
  final FinancialSummary summary;
  final List<RecurringExpense> recurringExpenses;
  final List<FinancialEntry> entries;
  final Map<String, String> studentNames;

  const _FinanceReportData({
    required this.settings,
    required this.summary,
    required this.recurringExpenses,
    required this.entries,
    required this.studentNames,
  });
}

class _PeriodSelector extends StatelessWidget {
  final String text;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.text,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: AppColors.white,
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              tooltip: 'Período anterior',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
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

class _PendingAlert extends StatelessWidget {
  final int count;

  const _PendingAlert({required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count comprovante(s) ainda aguardam análise. '
                'O fechamento poderá sofrer alterações.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_ReportRow> rows;

  const _SectionCard({
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
            const SizedBox(height: 14),
            for (var index = 0; index < rows.length; index++) ...[
              _ReportRowWidget(row: rows[index]),
              if (index < rows.length - 1) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportRow {
  final String label;
  final String value;
  final bool isStrong;
  final bool isWarning;

  const _ReportRow({
    required this.label,
    required this.value,
    this.isStrong = false,
    this.isWarning = false,
  });
}

class _ReportRowWidget extends StatelessWidget {
  final _ReportRow row;

  const _ReportRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final color = row.isWarning
        ? Colors.red.shade700
        : row.isStrong
        ? AppColors.brandPrimary
        : null;

    return Row(
      children: [
        Expanded(
          child: Text(
            row.label,
            style: TextStyle(
              fontWeight: row.isStrong ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          row.value,
          style: TextStyle(
            fontWeight: row.isStrong ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final Map<String, int> totals;
  final Color color;
  final String Function(int) formatCurrency;

  const _CategoryCard({
    required this.title,
    required this.totals,
    required this.color,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList()
      ..sort(
        (first, second) =>
            first.key.toLowerCase().compareTo(second.key.toLowerCase()),
      );

    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text(
                      formatCurrency(entry.value),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntriesCard extends StatelessWidget {
  final List<FinancialEntry> entries;
  final Map<String, String> studentNames;
  final String Function(int) formatCurrency;
  final String Function(DateTime) formatDate;

  const _EntriesCard({
    required this.entries,
    required this.studentNames,
    required this.formatCurrency,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        color: AppColors.white,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Nenhuma outra receita ou despesa foi registrada.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lançamentos detalhados',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...entries.map((entry) {
              final studentId = entry.studentId;
              final studentName = studentId == null
                  ? null
                  : studentNames[studentId];

              final color = entry.isIncome
                  ? Colors.green.shade700
                  : Colors.red.shade700;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.isIncome
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: entry.isCancelled ? Colors.grey : color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.description,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: entry.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          Text(
                            '${entry.category} • '
                            '${formatDate(entry.occurredAt)}',
                          ),
                          if (studentName != null) Text('Aluno: $studentName'),
                          if (entry.isCancelled)
                            const Text(
                              'Cancelado',
                              style: TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.isIncome ? '+' : '-'} '
                      '${formatCurrency(entry.amountCents)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: entry.isCancelled ? Colors.grey : color,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar o fechamento: $error',
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
