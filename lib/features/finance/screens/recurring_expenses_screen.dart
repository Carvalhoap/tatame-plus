import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/recurring_expense.dart';
import '../repository/finance_repository.dart';
import 'recurring_expense_form_screen.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> {
  Future<List<RecurringExpense>>? expensesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    expensesFuture ??= _loadExpenses();
  }

  Future<List<RecurringExpense>> _loadExpenses() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final expenses = await context
        .read<FinanceRepository>()
        .getRecurringExpenses(academyId: currentUser.academyId);

    expenses.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.description.toLowerCase().compareTo(
        second.description.toLowerCase(),
      );
    });

    return expenses;
  }

  Future<void> _reload() async {
    final nextFuture = _loadExpenses();

    setState(() {
      expensesFuture = nextFuture;
    });

    await nextFuture;
  }

  Future<void> _openForm([RecurringExpense? expense]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringExpenseFormScreen(expense: expense),
      ),
    );

    if (saved == true && mounted) {
      await _reload();
    }
  }

  String _formatCurrency(int cents) {
    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

    return 'R\$ $value';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Despesas fixas'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
      body: FutureBuilder<List<RecurringExpense>>(
        future: expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _reload);
          }

          final expenses = snapshot.data ?? const <RecurringExpense>[];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Card(
                  color: AppColors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.brandPrimary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cadastre professores, aluguel e outros custos '
                            'recorrentes. As despesas ativas serão consideradas '
                            'em cada fechamento financeiro.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (expenses.isEmpty)
                  const Card(
                    color: AppColors.white,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 42,
                            color: AppColors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nenhuma despesa fixa cadastrada.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...expenses.map(
                    (expense) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        color: AppColors.white,
                        child: ListTile(
                          onTap: () => _openForm(expense),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: expense.isActive
                                ? Colors.red.shade50
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.payments_outlined,
                              color: expense.isActive
                                  ? Colors.red.shade700
                                  : AppColors.grey,
                            ),
                          ),
                          title: Text(
                            expense.description,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${expense.category}\n'
                              '${expense.isActive ? 'Ativa' : 'Inativa'}',
                            ),
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatCurrency(expense.amountCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Icon(Icons.edit_outlined, size: 20),
                            ],
                          ),
                        ),
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
              size: 46,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar as despesas fixas:\n$error',
              textAlign: TextAlign.center,
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
