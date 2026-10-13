import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../currency/app_currency.dart';
import '../l10n/app_localizations.dart';
import '../models/investment_entry.dart';
import '../state/app_store.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/common_widgets.dart';
import 'investments_screen.dart';

Future<void> openInvestmentEntryEditor(
  BuildContext context,
  InvestmentEntry entry,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .94,
  ),
  builder: (context) {
    final theme = Theme.of(context);
    final background =
        theme.bottomSheetTheme.modalBackgroundColor ??
        theme.colorScheme.surface;
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: background,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: background,
          surfaceTintColor: theme.bottomSheetTheme.surfaceTintColor,
        ),
      ),
      child: InvestmentEntrySheet(entry: entry),
    );
  },
);

/// The centre add button's form while the dashboard is in investment mode.
class InvestmentEntrySheet extends ConsumerStatefulWidget {
  const InvestmentEntrySheet({super.key, this.entry});
  final InvestmentEntry? entry;
  @override
  ConsumerState<InvestmentEntrySheet> createState() =>
      _InvestmentEntrySheetState();
}

class _InvestmentEntrySheetState extends ConsumerState<InvestmentEntrySheet> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  int? fundId, accountId;
  DateTime date = DateTime.now();
  late final String? owner;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    owner = ref.read(appStoreProvider.notifier).activeAccountId;
    accountId = ref.read(appStoreProvider).accounts.firstOrNull?.id;
    final month = ref.read(appStoreProvider).selectedMonth;
    final now = DateTime.now();
    date = month.year == now.year && month.month == now.month ? now : month;
    final entry = widget.entry;
    if (entry != null) {
      fundId = entry.fundId;
      accountId = entry.accountId;
      date = entry.date;
      amount.text = (entry.amountMinor / 100).toStringAsFixed(2);
      note.text = entry.note;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final store = ref.read(appStoreProvider.notifier);
    if (owner != store.activeAccountId) {
      showAppAlert(
        context,
        context.l10n.t('export_account_changed'),
        isError: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await store.addInvestmentEntry(
        InvestmentEntry(
          id: widget.entry?.id,
          fundId: fundId!,
          accountId: accountId!,
          amountMinor: parseInvestmentAmount(amount.text)!,
          currentMinor: widget.entry?.currentMinor ?? 0,
          contributionOnly: widget.entry?.contributionOnly ?? true,
          date: date,
          createdAt:
              widget.entry?.createdAt ?? DateTime.now().microsecondsSinceEpoch,
          note: note.text,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        showAppAlert(context, context.l10n.t('save_failed'), isError: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.l10n.t('delete_investment_entry')),
        content: Text(context.l10n.t('delete_investment_entry_hint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.l10n.t('delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || saving) return;
    final store = ref.read(appStoreProvider.notifier);
    if (owner != store.activeAccountId) {
      showAppAlert(
        context,
        context.l10n.t('export_account_changed'),
        isError: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await store.deleteInvestmentEntry(widget.entry!.id!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        showAppAlert(context, context.l10n.t('save_failed'), isError: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final funds = state.investments
        .where(
          (f) =>
              f.id != null &&
              (f.currencyCode == state.currencyCode ||
                  f.id == widget.entry?.fundId),
        )
        .toList();
    final selected = funds.where((f) => f.id == fundId);
    final code = selected.isEmpty
        ? state.currencyCode
        : selected.first.currencyCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.t(
            widget.entry == null ? 'add_investment' : 'edit_investment',
          ),
        ),
        actions: [
          if (widget.entry?.id != null)
            IconButton(
              tooltip: context.l10n.t('delete'),
              onPressed: saving ? null : delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: funds.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(context.l10n.t('create_fund_first')),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => openFundEditor(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.t('add_fund')),
                ),
              ],
            )
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppDropdownFormField<int>(
                    initialValue: selected.isEmpty ? null : fundId,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('select_fund'),
                    ),
                    items: [
                      for (final f in funds)
                        DropdownMenuItem(
                          value: f.id,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: saving || widget.entry != null
                        ? null
                        : (v) => setState(() => fundId = v),
                    validator: (v) => v == null || !funds.any((f) => f.id == v)
                        ? context.l10n.t('select_fund')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  AppDropdownFormField<int>(
                    initialValue: accountId,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('account'),
                    ),
                    items: [
                      for (final account in state.accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.name == 'cash'
                                ? context.l10n.t('cash')
                                : account.name,
                          ),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() => accountId = v),
                    validator: (v) =>
                        v == null || !state.accounts.any((a) => a.id == v)
                        ? context.l10n.t('select_account')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${context.l10n.t('currency')}: ${currencySelectionLabels[code]}',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amount,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.t('investment_amount'),
                      prefixText: '${currencySymbols[code]} ',
                    ),
                    validator: (v) => (parseInvestmentAmount(v ?? '') ?? 0) <= 0
                        ? context.l10n.t('invalid_amount')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final now = DateTime.now();
                            final result = await showDatePicker(
                              context: context,
                              initialDate: date.isAfter(now) ? now : date,
                              firstDate: DateTime(2000),
                              lastDate: now,
                            );
                            if (result != null && mounted)
                              setState(() => date = result);
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      '${context.l10n.t('investment_date')}: ${DateFormat.yMd(state.languageCode).format(date)}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: note,
                    enabled: !saving,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.l10n.t('note'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: Text(context.l10n.t('save')),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
