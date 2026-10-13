import '../widgets/app_action_menu.dart';
import 'investment_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/investment.dart';
import '../state/app_store.dart';
import '../l10n/app_localizations.dart';
import '../currency/app_currency.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_dropdown.dart';

int? parseInvestmentAmount(String text) {
  final value = text.trim().replaceAll(',', '');
  if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

String investmentMoney(
  BuildContext context,
  int minor,
  String code,
  bool hidden,
) => hidden
    ? '******'
    : '${currencySymbols[code]}${NumberFormat('#,##0.00', Localizations.localeOf(context).languageCode).format(minor / 100)}';

Future<void> openFundEditor(
  BuildContext context,
  WidgetRef ref, [
  Investment? value,
]) async {
  final store = ref.read(appStoreProvider.notifier),
      owner = ref.read(appStoreProvider.notifier).activeAccountId;
  final result = await Navigator.push<Investment>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _InvestmentEditor(value: value, currencyCode: store.currencyCode),
    ),
  );
  if (result == null || !context.mounted) return;
  if (owner != store.activeAccountId) {
    showAppAlert(
      context,
      context.l10n.t('export_account_changed'),
      isError: true,
    );
    return;
  }
  try {
    await store.saveFund(result);
  } catch (_) {
    if (context.mounted)
      showAppAlert(context, context.l10n.t('save_failed'), isError: true);
  }
}

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider),
        store = ref.read(appStoreProvider.notifier);
    final rows = state.investments
        .where((v) => v.currencyCode == state.currencyCode)
        .toList();
    final cost = rows.fold<int>(0, (s, v) => s + v.investedMinor),
        current = rows.fold<int>(0, (s, v) => s + v.currentMinor);
    String moneyValue(int minor) =>
        investmentMoney(context, minor, state.currencyCode, state.hideBalances);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('investments'))),
      floatingActionButton: FloatingActionButton.extended(
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        onPressed: () => openFundEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.t('add_fund')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.t(
                    current == cost ? 'net_invested' : 'portfolio_value',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moneyValue(current),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (current != cost) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${context.l10n.t('net_invested')}: ${moneyValue(cost)}',
                  ),
                  Text(
                    '${context.l10n.t('investment_gain')}: ${moneyValue(current - cost)}',
                    style: TextStyle(
                      color: current >= cost
                          ? AppColors.categoryIncome
                          : AppColors.categoryExpense,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  context.l10n.t('investment_manual_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${context.l10n.t('currency')}: ${currencySelectionLabels[state.currencyCode]}',
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(context.l10n.t('no_portfolios')),
            ),
          if (state.investments.any(
            (v) => v.currencyCode != state.currencyCode,
          ))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.l10n.t('portfolio_currency_hint')),
            ),
          for (final item in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.investment.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: AppColors.investment,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AppActionMenu(
                          tooltip: context.l10n.t('edit'),
                          actions: [
                            (
                              'edit',
                              context.l10n.t('edit_fund'),
                              Icons.edit_outlined,
                            ),
                            if (!state.investmentEntries.any(
                              (e) => e.fundId == item.id && e.accountId != null,
                            ))
                              (
                                'delete',
                                context.l10n.t('delete'),
                                Icons.delete_outline,
                              ),
                          ],
                          onSelected: (action) async {
                            if (action == 'edit') {
                              await openFundEditor(context, ref, item);
                              return;
                            }
                            if (state.investmentEntries.any(
                              (e) => e.fundId == item.id && e.accountId != null,
                            )) {
                              showAppAlert(
                                context,
                                context.l10n.t('fund_has_deposits'),
                                isError: true,
                              );
                              return;
                            }
                            final owner = store.activeAccountId;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: Text(context.l10n.t('delete_portfolio')),
                                content: Text(item.name),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: Text(context.l10n.t('cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: Text(context.l10n.t('delete')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true ||
                                !context.mounted ||
                                owner != store.activeAccountId)
                              return;
                            try {
                              await store.deleteInvestment(item.id!);
                            } catch (_) {
                              if (context.mounted)
                                showAppAlert(
                                  context,
                                  context.l10n.t('save_failed'),
                                  isError: true,
                                );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.t('net_invested'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          moneyValue(item.investedMinor),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.investment,
                          ),
                        ),
                      ),
                    ),
                    if (item.gainMinor != 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${context.l10n.t('portfolio_value')}: ${moneyValue(item.currentMinor)}',
                      ),
                      Text(
                        '${context.l10n.t('investment_gain')}: ${moneyValue(item.gainMinor)}',
                        style: TextStyle(
                          color: item.gainMinor > 0
                              ? AppColors.categoryIncome
                              : AppColors.categoryExpense,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (item.note.isNotEmpty) Text(item.note),
                    if (state.investmentEntries.any((e) => e.fundId == item.id))
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          iconColor: AppColors.investment,
                          title: Text(
                            context.l10n.t('investment_history'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${state.investmentEntries.where((e) => e.fundId == item.id).length} ${context.l10n.t('export_rows')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          children: [
                            for (final entry in state.investmentEntries.where(
                              (e) => e.fundId == item.id,
                            ))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(moneyValue(entry.amountMinor)),
                                onTap: entry.accountId == null
                                    ? null
                                    : () => openInvestmentEntryEditor(
                                        context,
                                        entry,
                                      ),
                                trailing: entry.accountId == null
                                    ? null
                                    : IconButton(
                                        tooltip: context.l10n.t('edit'),
                                        onPressed: () =>
                                            openInvestmentEntryEditor(
                                              context,
                                              entry,
                                            ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                subtitle: Text(
                                  '${DateFormat.yMd(state.languageCode).format(entry.date)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InvestmentEditor extends StatefulWidget {
  const _InvestmentEditor({this.value, required this.currencyCode});
  final Investment? value;
  final String currencyCode;
  @override
  State<_InvestmentEditor> createState() => _InvestmentEditorState();
}

class _InvestmentEditorState extends State<_InvestmentEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, note;
  late String currency;
  late DateTime valuedAt;
  @override
  void initState() {
    super.initState();
    final item = widget.value;
    name = TextEditingController(text: item?.name);
    note = TextEditingController(text: item?.note);
    currency = item?.currencyCode ?? widget.currencyCode;
    valuedAt = item?.valuedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [name, note]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.l10n.t(widget.value == null ? 'add_fund' : 'edit_fund'),
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.l10n.t('investment_manual_hint')),
          const SizedBox(height: 16),
          TextFormField(
            controller: name,
            maxLength: 100,
            decoration: InputDecoration(labelText: context.l10n.t('fund_name')),
            validator: (v) => v == null || v.trim().isEmpty
                ? context.l10n.t('required_name')
                : null,
          ),
          const SizedBox(height: 14),
          AppDropdownFormField<String>(
            initialValue: currency,
            decoration: InputDecoration(labelText: context.l10n.t('currency')),
            items: [
              for (final c in currencySelectionLabels.entries)
                DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: widget.value == null ? (v) => currency = v! : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: note,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: context.l10n.t('note')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(
                context,
                Investment(
                  id: widget.value?.id,
                  name: name.text,
                  investedMinor: widget.value?.investedMinor ?? 0,
                  currentMinor: widget.value?.currentMinor ?? 0,
                  currencyCode: currency,
                  valuedAt: valuedAt,
                  note: note.text,
                ),
              );
            },
            child: Text(context.l10n.t('save')),
          ),
        ],
      ),
    ),
  );
}
