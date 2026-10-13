import '../widgets/app_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth/auth_providers.dart';
import '../export/excel_report.dart';
import '../export/export_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_primary_button.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final selectedYears = <int>{};
  int? accountId;
  int? categoryId;
  bool charts = true;
  bool generated = false;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    selectedYears.add(ref.read(appStoreProvider).selectedMonth.year);
  }

  ExcelReportData _report() {
    final store = ref.read(appStoreProvider.notifier);
    return ExcelReportData(
      ownerId: store.activeAccountId,
      options: ReportOptions(
        years: selectedYears,
        accountId: accountId,
        categoryId: categoryId,
        includeCharts: charts,
        language: store.languageCode,
        currencyCode: store.currencyCode,
        selectedMonth: ref.read(appStoreProvider).selectedMonth,
      ),
      entries: List.of(store.entries),
      investments: List.of(store.investments),
      investmentEntries: List.of(store.investmentEntries),
      categoryNames: {
        -1: context.l10n.t('investments'),
        for (final c in store.categories) c.id: categoryLabel(context, c),
      },
      accountNames: {
        for (final a in store.accounts)
          if (a.id != null) a.id!: a.name,
      },
    );
  }

  Future<String?> _destination() async {
    final account = ref.read(authSessionProvider).asData?.value;
    if (account == null) return 'device';
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.t('export_destination'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt_rounded),
                onPressed: () => Navigator.pop(sheetContext, 'device'),
                label: Text(context.l10n.t('export_save_device')),
              ),
              if (account.email != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.mail_outline_rounded),
                  onPressed: () => Navigator.pop(sheetContext, 'email'),
                  label: Text(context.l10n.t('export_send_email')),
                ),
                const SizedBox(height: 8),
                Text(
                  account.email!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(context.l10n.t('cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deliver(String destination) async {
    final controller = ref.read(exportControllerProvider.notifier);
    if (destination == 'email') {
      await controller.sendEmail();
    } else {
      final result = await controller.save();
      if (mounted && result) setState(() => saved = true);
    }
  }

  Future<void> _generate() async {
    final report = _report();
    final destination = await _destination();
    if (!mounted ||
        destination == null ||
        ref.read(authSessionProvider).asData?.value?.id != report.ownerId)
      return;
    final success = await ref
        .read(exportControllerProvider.notifier)
        .generate(report);
    if (!mounted || !success) return;
    setState(() {
      generated = true;
      saved = false;
    });
    await _deliver(destination);
  }

  Future<void> _exportReady() async {
    final owner = ref.read(authSessionProvider).asData?.value?.id;
    final destination = await _destination();
    if (!mounted ||
        destination == null ||
        ref.read(authSessionProvider).asData?.value?.id != owner)
      return;
    await _deliver(destination);
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStoreProvider);
    final account = ref.watch(authSessionProvider).asData?.value;
    final state = ref.watch(exportControllerProvider);
    final busy = state.busy;
    final ready = generated && state.bytes != null;
    final scheme = Theme.of(context).colorScheme;
    final years = {
      ...app.entries.map((e) => e.date.year),
      ...selectedYears,
      DateTime.now().year,
      ...List.generate(3, (i) => DateTime.now().year - i),
    }.toList()..sort((a, b) => b.compareTo(a));
    if (!app.accounts.any((a) => a.id == accountId)) accountId = null;
    if (!app.categories.any((c) => c.id == categoryId)) categoryId = null;
    final ownerReady =
        ref.read(appStoreProvider.notifier).activeAccountId == account?.id;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.t(ready ? 'export_ready' : 'export_excel')),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              if (!ready) ...[
                Text(context.l10n.t('export_subtitle')),
                const SizedBox(height: 14),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('export_years'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      for (final year in years)
                        AppSwitchTile(
                          title: '$year',
                          value: selectedYears.contains(year),
                          onChanged: (value) {
                            if (!busy)
                              setState(() {
                                if (value)
                                  selectedYears.add(year);
                                else
                                  selectedYears.remove(year);
                              });
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppDropdownFormField<int>(
                  key: ValueKey('export-account-$accountId'),
                  initialValue: accountId ?? -1,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('account'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: -1,
                      child: Text(context.l10n.t('export_all')),
                    ),
                    ...app.accounts
                        .where((a) => a.id != null)
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id!,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => accountId = v == -1 ? null : v),
                ),
                const SizedBox(height: 16),
                AppDropdownFormField<int>(
                  key: ValueKey('export-category-$categoryId'),
                  initialValue: categoryId ?? -1,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('category'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: -1,
                      child: Text(context.l10n.t('export_all')),
                    ),
                    ...app.categories.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          categoryLabel(context, c),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: categoryTextColor(context, c),
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => categoryId = v == -1 ? null : v),
                ),
                AppSwitchTile(
                  title: context.l10n.t('export_charts'),
                  value: charts,
                  onChanged: (v) {
                    if (!busy) setState(() => charts = v);
                  },
                ),
                const SizedBox(height: 14),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('export_sheets'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              context.l10n.t('export_reference_sheets'),
                            ),
                          ),
                          ...(selectedYears.toList()..sort()).map(
                            (y) => Chip(label: Text('$y')),
                          ),
                        ],
                      ),
                      Text(context.l10n.t('export_contents')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: busy || selectedYears.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ExcelPreviewScreen(data: _report()),
                          ),
                        ),
                  child: Text(context.l10n.t('export_preview')),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Surface(
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt_rounded,
                        color: scheme.primary,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.t('export_file_ready'),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(state.filename!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.t(
                          state.emailSent
                              ? 'export_email_success'
                              : saved
                              ? 'export_saved'
                              : 'export_local_ready',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (state.error != null) ...[
                Text(
                  context.l10n.t(state.error!),
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (busy) ...[
                Text(context.l10n.t(state.phase), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: state.progress),
                if (state.progress != null)
                  Text(
                    '${(state.progress! * 100).round()}%',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
              ],
              if (!ready)
                AppPrimaryButton(
                  onPressed: busy || selectedYears.isEmpty || !ownerReady
                      ? null
                      : _generate,
                  child: Text(context.l10n.t('export_create')),
                ),
              if (ready) ...[
                AppPrimaryButton(
                  onPressed: busy ? null : _exportReady,
                  child: Text(context.l10n.t('export_save_or_send')),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => generated = false),
                  child: Text(context.l10n.t('export_new')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ExcelPreviewScreen extends ConsumerStatefulWidget {
  const ExcelPreviewScreen({super.key, required this.data});
  final ExcelReportData data;
  @override
  ConsumerState<ExcelPreviewScreen> createState() => _ExcelPreviewScreenState();
}

class _ExcelPreviewScreenState extends ConsumerState<ExcelPreviewScreen> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    if (ref.watch(authSessionProvider).asData?.value?.id !=
        widget.data.ownerId) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.t('export_preview'))),
        body: Center(child: Text(context.l10n.t('export_account_changed'))),
      );
    }
    final years = widget.data.years;
    final year = selected == 0 ? null : years[selected - 1];
    final incomeMinor =
        year?.incomeMinor ?? years.fold<int>(0, (a, y) => a + y.incomeMinor);
    final expenseMinor =
        year?.expenseMinor ?? years.fold<int>(0, (a, y) => a + y.expenseMinor);
    final investmentMinor =
        year?.investmentMinor ??
        years.fold<int>(0, (a, y) => a + y.investmentMinor);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('export_preview'))),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.l10n.t('export_overview')),
                  selected: selected == 0,
                  onSelected: (_) => setState(() => selected = 0),
                ),
                for (var i = 0; i < years.length; i++)
                  ChoiceChip(
                    label: Text('${years[i].year}'),
                    selected: selected == i + 1,
                    onSelected: (_) => setState(() => selected = i + 1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Surface(
              child: Column(
                children: [
                  Text(
                    year == null
                        ? context.l10n.t('export_overview')
                        : '${year.year}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(context.l10n.t('fund_count'))),
                      Text('${widget.data.fundCount}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${context.l10n.t('monthly_invested')} (${monthLabel(context, widget.data.investmentMonth)})',
                        ),
                      ),
                      Flexible(
                        child: Text(
                          money(
                            context,
                            widget.data.investedInMonth(
                              widget.data.investmentMonth,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.investment),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final pair in [
                    ('income', incomeMinor),
                    ('expense', expenseMinor),
                    (
                      'export_net',
                      incomeMinor - expenseMinor - investmentMinor,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(context.l10n.t(pair.$1))),
                          Flexible(
                            child: Text(
                              money(context, pair.$2),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t(
                      year == null ? 'export_years' : 'export_monthly',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (year != null && widget.data.options.includeCharts) ...[
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          ),
                          barGroups: List.generate(
                            12,
                            (i) => BarChartGroupData(
                              x: i + 1,
                              barRods: [
                                BarChartRodData(
                                  toY: year.monthTotal(i + 1, income) / 100,
                                  color: AppColors.teal,
                                  width: 6,
                                ),
                                BarChartRodData(
                                  toY: year.monthTotal(i + 1, expense) / 100,
                                  color: AppColors.expense,
                                  width: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${context.l10n.t('income')} / ${context.l10n.t('expense')} · ${widget.data.options.currencyCode}',
                    ),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(
                          label: Text(
                            context.l10n.t(
                              year == null ? 'export_year' : 'export_month',
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(context.l10n.t('income')),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(context.l10n.t('expense')),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(context.l10n.t('export_net')),
                          numeric: true,
                        ),
                      ],
                      rows: year == null
                          ? years
                                .map(
                                  (y) => DataRow(
                                    cells: [
                                      DataCell(Text('${y.year}')),
                                      DataCell(
                                        Text(money(context, y.incomeMinor)),
                                      ),
                                      DataCell(
                                        Text(money(context, y.expenseMinor)),
                                      ),
                                      DataCell(
                                        Text(money(context, y.netMinor)),
                                      ),
                                    ],
                                  ),
                                )
                                .toList()
                          : List.generate(12, (i) {
                              final a = year.monthTotal(i + 1, income),
                                  b = year.monthTotal(i + 1, expense);
                              return DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(Text(money(context, a))),
                                  DataCell(Text(money(context, b))),
                                  DataCell(Text(money(context, a - b))),
                                ],
                              );
                            }),
                    ),
                  ),
                ],
              ),
            ),
            if (year != null) ...[
              const SizedBox(height: 16),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.t('export_transactions'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${year.entries.length} ${context.l10n.t('export_rows')}',
                    ),
                    if (year.entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(context.l10n.t('export_no_data')),
                      ),
                    for (final e in year.entries.take(30))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.title),
                        subtitle: Text(
                          '${dateLabel(context, e.date)} · '
                          '${widget.data.categoryNames[e.categoryId] ?? ''}',
                        ),
                        trailing: Text(
                          money(context, e.amountMinor),
                          style: TextStyle(
                            color: e.type == investmentTransfer
                                ? AppColors.investment
                                : e.type == income
                                ? AppColors.teal
                                : AppColors.expense,
                          ),
                        ),
                      ),
                    if (year.entries.length > 30)
                      Text(context.l10n.t('export_preview_limit')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
