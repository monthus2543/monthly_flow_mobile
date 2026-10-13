import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStoreProvider);
    final store = ref.read(appStoreProvider.notifier);
    final rows = store.monthlyEntries.toList()
      ..sort((a, b) {
        final byDate = DateUtils.dateOnly(
          a.date,
        ).compareTo(DateUtils.dateOnly(b.date));
        if (byDate != 0) return byDate;
        final byCreation = a.createdAt.compareTo(b.createdAt);
        if (byCreation != 0) return byCreation;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final incomeTotal = store.monthlyIncome;
    final expenseTotal = store.monthlyExpense;
    final balance =
        incomeTotal - expenseTotal - sumType(rows, investmentTransfer);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final incomeColor = theme.brightness == Brightness.dark
        ? AppColors.tealDark
        : brandGreen;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
      children: [
        PageTitle(
          context.l10n.t('statistics'),
          context.l10n.t('stats_subtitle'),
        ),
        MonthButton(),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('income_expense_summary'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 58,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: _sections(incomeTotal, expenseTotal, context),
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.t('balance'),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          money(context, balance),
                          style: TextStyle(
                            color: balance < 0 ? colors.error : colors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SummaryLegend(
                color: incomeColor,
                label: context.l10n.t('income'),
                amount: incomeTotal,
              ),
              const SizedBox(height: 9),
              _SummaryLegend(
                color: colors.error,
                label: context.l10n.t('expense'),
                amount: expenseTotal,
              ),
              const SizedBox(height: 9),
              _SummaryLegend(
                color: balance < 0 ? colors.error : colors.primary,
                label: context.l10n.t('balance'),
                amount: balance,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          Surface(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.insert_chart_outlined_rounded,
                    size: 44,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.t('no_data'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.t('no_entries'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t('transaction_table'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _TransactionTable(rows: rows, balance: balance),
              ],
            ),
          ),
      ],
    );
  }

  List<PieChartSectionData> _sections(
    int incomeTotal,
    int expenseTotal,
    BuildContext context,
  ) {
    final values = [incomeTotal, expenseTotal];
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: .55),
          radius: 38,
          showTitle: false,
        ),
      ];
    }
    final colors = [
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.tealDark
          : brandGreen,
      Theme.of(context).colorScheme.error,
    ];
    return [
      for (var index = 0; index < values.length; index++)
        if (values[index] > 0)
          PieChartSectionData(
            value: values[index].toDouble(),
            color: colors[index],
            radius: 38,
            showTitle: values[index] / math.max(1, total) >= .09,
            title: '${(values[index] * 100 / math.max(1, total)).round()}%',
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
    ];
  }
}

class _SummaryLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int amount;
  const _SummaryLegend({
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(
        money(context, amount),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _TransactionTable extends StatelessWidget {
  final List<Entry> rows;
  final int balance;
  const _TransactionTable({required this.rows, required this.balance});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Table(
      columnWidths: const {
        0: FlexColumnWidth(1.7),
        1: FlexColumnWidth(1.15),
        2: FlexColumnWidth(1.15),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Theme.of(context).dividerColor),
        bottom: BorderSide(color: Theme.of(context).dividerColor),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          children: [
            _cell(
              context.l10n.t('name'),
              header: true,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            _cell(
              context.l10n.t('income'),
              header: true,
              align: TextAlign.right,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            _cell(
              context.l10n.t('expense'),
              header: true,
              align: TextAlign.right,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
        ),
        for (final entry in rows)
          TableRow(
            children: [
              _cell(entry.title),
              _cell(
                entry.type == income
                    ? '+${_plainAmount(context, entry.amountMinor)}'
                    : '',
                align: TextAlign.right,
                color: entry.type == income
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.tealDark
                          : brandGreen)
                    : null,
                emphasized: entry.type == income,
              ),
              _cell(
                entry.type != income
                    ? '−${_plainAmount(context, entry.amountMinor)}'
                    : '',
                align: TextAlign.right,
                color: entry.type == investmentTransfer
                    ? AppColors.investment
                    : entry.type == expense
                    ? Theme.of(context).colorScheme.error
                    : null,
                emphasized: entry.type == expense,
              ),
            ],
          ),
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: [
            _cell(context.l10n.t('balance'), header: true),
            _cell(''),
            _cell(
              _plainAmount(context, balance.abs()),
              header: true,
              align: TextAlign.right,
              color: balance < 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _cell(
    String text, {
    bool header = false,
    bool emphasized = false,
    Color? color,
    TextAlign align = TextAlign.left,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: header || emphasized ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

String _plainAmount(BuildContext context, int minor) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 2,
    ).format(minor / 100);
