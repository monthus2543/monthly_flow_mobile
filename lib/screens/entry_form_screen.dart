import '../widgets/app_dropdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/receipt_preview.dart';
import '../receipts/receipt_storage.dart';
import '../receipts/receipt_cloud.dart';

class EntryFormScreen extends ConsumerStatefulWidget {
  final Entry? existing;
  final String? initialType;
  final Entry? initial;
  const EntryFormScreen({
    super.key,
    this.existing,
    this.initialType,
    this.initial,
  });
  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  AppStore get store => ref.read(appStoreProvider.notifier);
  late final TextEditingController title;
  late final TextEditingController amount;
  late final TextEditingController note;
  late final TextEditingController numberOfMonths;
  late final FocusNode amountFocus;
  late DateTime date;
  late String type;
  int? categoryId;
  int accountId = 1;
  String receiptPath = '';
  bool isFavorite = false;
  bool saving = false;
  bool pickingReceipt = false;
  double? receiptProgress;
  bool repeatMonthly = false;
  bool noEndDate = false;
  late DateTime startMonth;
  late final CurrencyTextInputFormatter amountFormatter;

  @override
  void initState() {
    super.initState();
    amountFormatter = CurrencyTextInputFormatter.currency(
      locale: 'th_TH',
      symbol: '',
      decimalDigits: 2,
      inputDirection: InputDirection.left,
    );
    final entry = widget.existing ?? widget.initial;
    title = TextEditingController(text: entry?.title ?? '');
    amount = TextEditingController(
      text: entry == null ? '' : (entry.amountMinor / 100).toStringAsFixed(2),
    );
    amountFocus = FocusNode()..addListener(_handleAmountFocus);
    note = TextEditingController(text: entry?.note ?? '');
    numberOfMonths = TextEditingController(text: '12');
    final now = DateTime.now();
    final selectedMonth = store.selectedMonth;
    final lastDay = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;
    date =
        entry?.date ??
        (sameMonth(now, selectedMonth)
            ? now
            : DateTime(
                selectedMonth.year,
                selectedMonth.month,
                now.day.clamp(1, lastDay),
              ));
    startMonth = DateTime(date.year, date.month);
    type = entry?.type ?? widget.initialType ?? expense;
    categoryId = entry?.categoryId;
    accountId = entry?.accountId ?? (store.accounts.firstOrNull?.id ?? 1);
    receiptPath = entry?.receiptPath ?? '';
    isFavorite = entry?.isFavorite ?? false;
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    note.dispose();
    numberOfMonths.dispose();
    amountFocus
      ..removeListener(_handleAmountFocus)
      ..dispose();
    super.dispose();
  }

  void _handleAmountFocus() {
    if (!amountFocus.hasFocus) _formatAmount();
  }

  void _formatAmount() {
    final value = double.tryParse(amount.text.trim().replaceAll(',', ''));
    if (value == null) return;
    final formatted = value.toStringAsFixed(2);
    amount.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  int? _minor(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;
    return (parsed * 100).round();
  }

  Future<void> _save(BuildContext formContext) async {
    if (!(Form.maybeOf(formContext)?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final owner = store.activeAccountId;
      if (receiptCloudEnabled &&
          owner != null &&
          receiptPath.isNotEmpty &&
          !isCloudReceipt(receiptPath)) {
        final cloudPath = await ref
            .read(receiptCloudProvider)
            .upload(
              owner,
              receiptPath,
              onProgress: (progress) {
                if (mounted) setState(() => receiptProgress = progress);
              },
            );
        if (!mounted || store.activeAccountId != owner) return;
        setState(() {
          receiptPath = cloudPath;
          receiptProgress = null;
        });
      }
      final now = DateTime.now().microsecondsSinceEpoch;
      final entry = Entry(
        id: widget.existing?.id,
        title: title.text.trim(),
        amountMinor: _minor(amount.text)!,
        type: type,
        categoryId: categoryId!,
        date: date,
        note: note.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
        accountId: accountId,
        receiptPath: receiptPath,
        isFavorite: isFavorite,
      );
      if (repeatMonthly && widget.existing == null) {
        if (noEndDate) {
          await store.saveIndefiniteMonthlyEntry(entry, startMonth);
        } else {
          await store.saveMonthlyEntries(
            entry,
            startMonth,
            int.parse(numberOfMonths.text),
          );
        }
      } else {
        await store.save(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        showAppAlert(
          context,
          context.l10n.t(
            error is ReceiptCloudFailure ? error.key : 'save_failed',
          ),
          isError: true,
        );
    } finally {
      if (mounted)
        setState(() {
          saving = false;
          receiptProgress = null;
        });
    }
  }

  Future<void> _pickReceipt() async {
    if (pickingReceipt || saving) return;
    setState(() => pickingReceipt = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      final documents = await getApplicationDocumentsDirectory();
      final storedPath = await storeReceipt(picked, documents);
      if (mounted) setState(() => receiptPath = storedPath);
    } catch (_) {
      if (mounted)
        showAppAlert(
          context,
          context.l10n.t('receipt_attach_failed'),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => pickingReceipt = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.t('delete_title')),
        content: Text(context.l10n.t('delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.delete(id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        showAppAlert(context, context.l10n.t('delete_failed'), isError: true);
    }
  }

  Widget _recurrenceOptions(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(context.l10n.t('repeat_monthly')),
        subtitle: Text(context.l10n.t('repeat_monthly_hint')),
        value: repeatMonthly,
        onChanged: (value) => setState(() {
          repeatMonthly = value ?? false;
          if (repeatMonthly) {
            startMonth = DateTime(date.year, date.month);
          } else {
            noEndDate = false;
          }
        }),
      ),
      if (repeatMonthly) ...[
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startMonth,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => startMonth = DateTime(picked.year, picked.month));
            }
          },
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            '${context.l10n.t('start_month')}: ${MaterialLocalizations.of(context).formatMonthYear(startMonth)}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: numberOfMonths,
                enabled: !noEndDate,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.t('number_of_months'),
                ),
                validator: (value) {
                  if (!repeatMonthly || noEndDate) return null;
                  final parsed = int.tryParse(value ?? '');
                  return parsed == null || parsed < 1 || parsed > 120
                      ? context.l10n.t('invalid_month_count')
                      : null;
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(context.l10n.t('no_end_date')),
                value: noEndDate,
                onChanged: (value) =>
                    setState(() => noEndDate = value ?? false),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBottomSheet = ModalRoute.of(context) is ModalBottomSheetRoute;
    final surface = isBottomSheet
        ? theme.bottomSheetTheme.modalBackgroundColor ?? scheme.surface
        : scheme.surface;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: isBottomSheet ? surface : Colors.transparent,
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: isBottomSheet ? surface : Colors.transparent,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          fillColor: scheme.surfaceContainerLowest,
          border: border,
          enabledBorder: border,
        ),
      ),
      child: Builder(
        builder: (formContext) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: isBottomSheet ? null : appBackgroundGradient(formContext),
          ),
          child: _buildForm(formContext),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final options = store.categories.where((c) => c.type == type).toList();
    final selected = options.any((c) => c.id == categoryId) ? categoryId : null;
    final heading = widget.existing != null
        ? context.l10n.t('edit_entry')
        : context.l10n.t(type == income ? 'add_income' : 'add_expense');
    return Scaffold(
      appBar: AppBar(
        title: Text(heading),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: _delete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            children: [
              Text(
                context.l10n.t('form_hint'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              AppSegmentedControl(
                segments: transactionTypeSegments(context),
                value: type,
                onChanged: (selection) => setState(() {
                  type = selection;
                  if (!options.any((c) => c.id == categoryId && c.type == type))
                    categoryId = null;
                }),
              ),
              if (widget.existing == null) ...[
                const SizedBox(height: 8),
                _recurrenceOptions(context),
              ],
              const SizedBox(height: 15),
              TextFormField(
                controller: amount,
                focusNode: amountFocus,
                inputFormatters: [amountFormatter],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: store.currencyCode == 'THB'
                      ? context.l10n.t('amount')
                      : context.l10n
                            .t('amount_currency')
                            .replaceAll('{currency}', store.currencyCode),
                  prefixIcon: const Icon(LucideIcons.walletCards),
                  suffixIcon: amount.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(amount.clear),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onEditingComplete: () {
                  _formatAmount();
                  FocusScope.of(context).nextFocus();
                },
                validator: (value) => _minor(value ?? '') == null
                    ? context.l10n.t('invalid_amount')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: title,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: context.l10n.t('title'),
                  prefixIcon: const Icon(LucideIcons.textCursorInput),
                  hintText: context.l10n.t('title_hint'),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? context.l10n.t('required_title')
                    : null,
              ),
              const SizedBox(height: 14),
              AppDropdownFormField<int>(
                key: ValueKey(type),
                initialValue: selected,
                decoration: InputDecoration(
                  labelText: context.l10n.t('category'),
                ),
                items: [
                  for (final category in options)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        categoryLabel(context, category),
                        style: TextStyle(
                          color: categoryTextColor(context, category),
                        ),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
                validator: (value) =>
                    value == null ? context.l10n.t('required_category') : null,
              ),
              const SizedBox(height: 14),
              AppDropdownFormField<int>(
                initialValue: accountId,
                decoration: InputDecoration(
                  labelText: context.l10n.t('account'),
                ),
                items: [
                  for (final account in store.accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        account.name == 'cash'
                            ? context.l10n.t('cash')
                            : account.name,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => accountId = value);
                },
              ),
              const SizedBox(height: 8),
              AppSwitchTile(
                title: context.l10n.t('favorite'),
                value: isFavorite,
                onChanged: (value) => setState(() => isFavorite = value),
              ),
              OutlinedButton.icon(
                onPressed: pickingReceipt || saving ? null : _pickReceipt,
                icon: Icon(
                  receiptPath.isEmpty
                      ? Icons.add_a_photo_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  context.l10n.t(
                    receiptPath.isEmpty ? 'attach_receipt' : 'receipt_attached',
                  ),
                ),
              ),
              if (receiptPath.isNotEmpty) ...[
                ReceiptPreview(path: receiptPath),
                if (receiptProgress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: receiptProgress),
                  Text(context.l10n.t('receipt_uploading')),
                ],
                TextButton.icon(
                  onPressed: saving || pickingReceipt
                      ? null
                      : () => setState(() => receiptPath = ''),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(context.l10n.t('remove_receipt')),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(dateLabel(context, date)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: note,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(labelText: context.l10n.t('note')),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (formContext) => AppPrimaryButton(
                  onPressed: saving || pickingReceipt
                      ? null
                      : () => _save(formContext),
                  child: Text(context.l10n.t(saving ? 'saving' : 'save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
