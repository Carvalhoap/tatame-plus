import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_summary.dart';

class FinanceReportPdfService {
  const FinanceReportPdfService._();

  static Future<Uint8List> build({
    required FinancialSummary summary,
    required FinanceSettings settings,
    required List<FinancialEntry> entries,
    required Map<String, String> studentNames,
  }) async {
    final document = pw.Document();

    final activeEntries = entries
        .where((entry) => entry.isActive)
        .toList(growable: false);

    final incomeByCategory = _totalsByCategory(
      activeEntries.where((entry) => entry.isIncome),
    );

    final expensesByCategory = _totalsByCategory(
      activeEntries.where((entry) => entry.isExpense),
    );

    final sortedEntries = [...entries]
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Relatório financeiro',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Documento gerado pelo sistema de gestão da academia.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
        build: (context) {
          return [
            pw.SizedBox(height: 12),
            pw.Text(
              'Fechamento financeiro',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Período: '
              '${_formatDate(summary.period.start)} a '
              '${_formatDate(summary.period.displayEnd)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 20),
            if (summary.pendingProofsCount > 0) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Atenção: existem '
                  '${summary.pendingProofsCount} comprovantes pendentes. '
                  'Os valores poderão mudar após a análise.',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange900,
                  ),
                ),
              ),
              pw.SizedBox(height: 18),
            ],
            _sectionTitle('Composição da receita'),
            _moneyTable([
              _MoneyRow(
                label: 'Mensalidades compartilhadas com a Moving',
                amountCents: summary.sharedMonthlyFeeRevenueCents,
              ),
              _MoneyRow(
                label: 'Mensalidades recebidas diretamente pela equipe',
                amountCents: summary.directMonthlyFeeRevenueCents,
              ),
              _MoneyRow(
                label: 'Gympass compartilhado com a Moving',
                amountCents: summary.gympassRevenueCents,
              ),
              _MoneyRow(
                label: 'Outras receitas integrais da equipe',
                amountCents: summary.otherIncomeCents,
              ),
              _MoneyRow(
                label: 'Base compartilhada com a Moving',
                amountCents: summary.movingSharedRevenueBaseCents,
              ),
              _MoneyRow(
                label: 'Receita bruta total',
                amountCents: summary.grossRevenueCents,
                isStrong: true,
              ),
            ]),
            pw.SizedBox(height: 20),
            _sectionTitle('Divisão e deduções'),
            _moneyTable([
              _MoneyRow(
                label:
                    'Parte da Moving (${settings.movingFitnessPercentage}% da base compartilhada)',
                amountCents: summary.movingFitnessShareCents,
              ),
              _MoneyRow(
                label: 'Parte total da equipe antes das despesas',
                amountCents: summary.academyShareCents,
                isStrong: true,
              ),
              _MoneyRow(
                label: settings.instructorName,
                amountCents: summary.instructorCostCents,
              ),
              _MoneyRow(
                label: 'Outras despesas',
                amountCents: summary.otherExpensesCents,
              ),
              _MoneyRow(
                label: 'Disponível após deduções',
                amountCents: summary.availableAfterDeductionsCents,
                isStrong: true,
              ),
              if (summary.hasDeficit)
                _MoneyRow(
                  label: 'Déficit do período',
                  amountCents: summary.deficitCents,
                  isStrong: true,
                  isWarning: true,
                ),
              _MoneyRow(
                label:
                    'Reserva Gracie Barra '
                    '(${settings.gracieBarraReservePercentage}%)',
                amountCents: summary.gracieBarraReserveCents,
              ),
              _MoneyRow(
                label: 'Total destinado aos sócios',
                amountCents: summary.partnersTotalCents,
              ),
              _MoneyRow(
                label:
                    'Valor por sócio '
                    '(${settings.remainingPartnersCount} sócios)',
                amountCents: summary.amountPerPartnerCents,
                isStrong: true,
              ),
            ]),
            if (incomeByCategory.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _categoryTable(
                title: 'Outras receitas por categoria',
                totals: incomeByCategory,
              ),
            ],
            if (expensesByCategory.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _categoryTable(
                title: 'Outras despesas por categoria',
                totals: expensesByCategory,
              ),
            ],
            pw.SizedBox(height: 20),
            _sectionTitle('Lançamentos detalhados'),
            if (sortedEntries.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                color: PdfColors.grey100,
                child: pw.Text(
                  'Nenhuma outra receita ou despesa foi registrada.',
                ),
              )
            else
              _entriesTable(entries: sortedEntries, studentNames: studentNames),
            pw.SizedBox(height: 16),
            pw.Text(
              'Gerado em ${_formatDateTime(DateTime.now())}.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo900,
        ),
      ),
    );
  }

  static pw.Widget _moneyTable(List<_MoneyRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.4),
      },
      children: rows.map((row) {
        final style = pw.TextStyle(
          fontSize: 10,
          fontWeight: row.isStrong ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: row.isWarning ? PdfColors.red800 : PdfColors.black,
        );

        return pw.TableRow(
          decoration: row.isStrong
              ? const pw.BoxDecoration(color: PdfColors.blueGrey50)
              : null,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(row.label, style: style),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                _formatCurrency(row.amountCents),
                textAlign: pw.TextAlign.right,
                style: style,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _categoryTable({
    required String title,
    required Map<String, int> totals,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        _moneyTable(
          totals.entries
              .map(
                (entry) =>
                    _MoneyRow(label: entry.key, amountCents: entry.value),
              )
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _entriesTable({
    required List<FinancialEntry> entries,
    required Map<String, String> studentNames,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
        children: [
          _tableCell('Data', isHeader: true),
          _tableCell('Tipo', isHeader: true),
          _tableCell('Categoria e descrição', isHeader: true),
          _tableCell('Aluno', isHeader: true),
          _tableCell('Valor', isHeader: true, alignRight: true),
        ],
      ),
    ];

    for (final entry in entries) {
      final studentId = entry.studentId;

      final studentName = studentId == null
          ? '-'
          : studentNames[studentId] ?? studentId;

      rows.add(
        pw.TableRow(
          decoration: entry.isCancelled
              ? const pw.BoxDecoration(color: PdfColors.grey200)
              : null,
          children: [
            _tableCell(_formatDate(entry.occurredAt)),
            _tableCell(
              entry.isCancelled
                  ? 'Cancelado'
                  : entry.isIncome
                  ? 'Receita'
                  : 'Despesa',
            ),
            _tableCell('${entry.category}\n${entry.description}'),
            _tableCell(studentName),
            _tableCell(
              '${entry.isIncome ? '+' : '-'} '
              '${_formatCurrency(entry.amountCents)}',
              alignRight: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.2),
      },
      children: rows,
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static Map<String, int> _totalsByCategory(Iterable<FinancialEntry> entries) {
    final totals = <String, int>{};

    for (final entry in entries) {
      totals.update(
        entry.category,
        (value) => value + entry.amountCents,
        ifAbsent: () => entry.amountCents,
      );
    }

    final sortedTotals = totals.entries.toList()
      ..sort(
        (first, second) =>
            first.key.toLowerCase().compareTo(second.key.toLowerCase()),
      );

    return Map.fromEntries(sortedTotals);
  }

  static String _formatCurrency(int amountCents) {
    final absoluteCents = amountCents.abs();
    final reais = absoluteCents ~/ 100;
    final cents = (absoluteCents % 100).toString().padLeft(2, '0');

    final characters = reais.toString().split('').reversed.toList();
    final groups = <String>[];

    for (var index = 0; index < characters.length; index += 3) {
      final end = index + 3 < characters.length ? index + 3 : characters.length;

      groups.add(characters.sublist(index, end).reversed.join());
    }

    final formattedReais = groups.reversed.join('.');
    final sign = amountCents < 0 ? '- ' : '';

    return '${sign}R\$ $formattedReais,$cents';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  static String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${_formatDate(date)} às $hour:$minute';
  }
}

class _MoneyRow {
  final String label;
  final int amountCents;
  final bool isStrong;
  final bool isWarning;

  const _MoneyRow({
    required this.label,
    required this.amountCents,
    this.isStrong = false,
    this.isWarning = false,
  });
}
