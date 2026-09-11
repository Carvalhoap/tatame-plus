import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/financial_entry.dart';
import '../repository/finance_repository.dart';
import 'financial_entry_form_screen.dart';

class FinancialEntriesScreen extends StatefulWidget {
  const FinancialEntriesScreen({super.key});

  @override
  State<FinancialEntriesScreen> createState() => _FinancialEntriesScreenState();
}

class _FinancialEntriesScreenState extends State<FinancialEntriesScreen> {
  late FinancePeriod period;
  Future<_FinancialEntriesData>? dataFuture;
  String? cancellingEntryId;

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

  Future<_FinancialEntriesData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final results = await Future.wait<Object>([
      context.read<FinanceRepository>().getFinancialEntries(
        academyId: currentUser.academyId,
        period: period,
      ),
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
    ]);

    final entries = results[0] as List<FinancialEntry>;
    final students = results[1] as List<Student>;

    return _FinancialEntriesData(
      entries: entries,
      studentsById: {for (final student in students) student.id: student},
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

  Future<void> openEntryForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FinancialEntryFormScreen(period: period),
      ),
    );

    if (created != true || !mounted) {
      return;
    }

    await reload();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento salvo com sucesso.')),
    );
  }

  Future<void> cancelEntry(FinancialEntry entry) async {
    if (cancellingEntryId != null || entry.isCancelled) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;
    final repository = context.read<FinanceRepository>();

    if (currentUser == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar lançamento?'),
          content: Text(
            'O lançamento "${entry.description}" continuará no histórico, '
            'mas não será considerado no fechamento financeiro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancelar lançamento'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      cancellingEntryId = entry.id;
    });

    try {
      await repository.cancelFinancialEntry(
        academyId: currentUser.academyId,
        entryId: entry.id,
        cancelledBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      await reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lançamento cancelado.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível cancelar o lançamento: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          cancellingEntryId = null;
        });
      }
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String formatCurrency(int amountCents) {
    final amount = (amountCents / 100).toStringAsFixed(2).replaceAll('.', ',');

    return 'R\$ $amount';
  }

  String paymentMethodLabel(PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.pix:
        return 'Pix';
      case PaymentMethod.cash:
        return 'Dinheiro';
      case PaymentMethod.card:
        return 'Cartão';
      case PaymentMethod.bankTransfer:
        return 'Transferência';
      case PaymentMethod.gympass:
        return 'Gympass';
      case PaymentMethod.other:
        return 'Outro';
      case null:
        return 'Não informada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Receitas e despesas'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openEntryForm,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo lançamento'),
      ),
      body: Column(
        children: [
          _PeriodSelector(
            periodText:
                '${formatDate(period.start)} a '
                '${formatDate(period.displayEnd)}',
            onPrevious: () => movePeriod(-1),
            onNext: () => movePeriod(1),
          ),
          Expanded(
            child: FutureBuilder<_FinancialEntriesData>(
              future: dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(error: snapshot.error, onRetry: reload);
                }

                final data = snapshot.data!;

                final activeEntries = data.entries
                    .where((entry) => entry.isActive)
                    .toList();

                final incomeCents = activeEntries
                    .where((entry) => entry.isIncome)
                    .fold<int>(0, (total, entry) => total + entry.amountCents);

                final expenseCents = activeEntries
                    .where((entry) => entry.isExpense)
                    .fold<int>(0, (total, entry) => total + entry.amountCents);

                final balanceCents = incomeCents - expenseCents;

                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    children: [
                      _SummaryCard(
                        income: formatCurrency(incomeCents),
                        expenses: formatCurrency(expenseCents),
                        balance: formatCurrency(balanceCents),
                        isNegative: balanceCents < 0,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lançamentos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (data.entries.isEmpty)
                        const _EmptyState()
                      else
                        ...data.entries.map((entry) {
                          final studentName =
                              data.studentsById[entry.studentId]?.fullName;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EntryCard(
                              entry: entry,
                              studentName: studentName,
                              amount: formatCurrency(entry.amountCents),
                              date: formatDate(entry.occurredAt),
                              paymentMethod: paymentMethodLabel(
                                entry.paymentMethod,
                              ),
                              isCancelling: cancellingEntryId == entry.id,
                              onCancel: () => cancelEntry(entry),
                            ),
                          );
                        }),
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

class _FinancialEntriesData {
  final List<FinancialEntry> entries;
  final Map<String, Student> studentsById;

  const _FinancialEntriesData({
    required this.entries,
    required this.studentsById,
  });
}

class _PeriodSelector extends StatelessWidget {
  final String periodText;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.periodText,
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
                periodText,
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

class _SummaryCard extends StatelessWidget {
  final String income;
  final String expenses;
  final String balance;
  final bool isNegative;

  const _SummaryCard({
    required this.income,
    required this.expenses,
    required this.balance,
    required this.isNegative,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Outras receitas',
              value: income,
              color: Colors.green.shade700,
              icon: Icons.trending_up,
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Outras despesas',
              value: expenses,
              color: Colors.red.shade700,
              icon: Icons.trending_down,
            ),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Resultado dos lançamentos',
              value: balance,
              color: isNegative ? Colors.red.shade700 : AppColors.brandPrimary,
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final FinancialEntry entry;
  final String? studentName;
  final String amount;
  final String date;
  final String paymentMethod;
  final bool isCancelling;
  final VoidCallback onCancel;

  const _EntryCard({
    required this.entry,
    required this.studentName,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.isCancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.isIncome ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      color: entry.isCancelled ? Colors.grey.shade100 : AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                entry.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: entry.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.isIncome ? '+' : '-'} $amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: entry.isCancelled ? Colors.grey : color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(entry.category),
                  const SizedBox(height: 4),
                  Text(
                    '$date • $paymentMethod',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (studentName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Aluno: $studentName',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  if (entry.isCancelled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Lançamento cancelado',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: isCancelling ? null : onCancel,
                        icon: isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.brandPrimary,
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum lançamento neste período.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Use o botão “Novo lançamento” para registrar '
              'uma receita ou despesa.',
              textAlign: TextAlign.center,
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os lançamentos: $error',
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
