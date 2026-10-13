import '../color/color.dart';
import '../currency/app_currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/finance_models.dart';
import '../state/app_store.dart';
import 'app_segmented_control.dart';

export '../color/color.dart';
export 'app_alert.dart';
export 'app_segmented_control.dart';
export 'app_switch_tile.dart';

Color categoryTextColor(BuildContext context, Category category) {
  if (category.colorValue != null) return Color(category.colorValue!);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return category.type == income
      ? (dark ? AppColors.tealDark : AppColors.categoryIncome)
      : (dark ? AppColors.errorDark : AppColors.categoryExpense);
}

List<AppSegment> transactionTypeSegments(BuildContext context) => [
  AppSegment(
    expense,
    context.l10n.t('expense'),
    Icons.north_east,
    color: Theme.of(context).colorScheme.error,
  ),
  AppSegment(
    income,
    context.l10n.t('income'),
    Icons.south_west,
    color: Theme.of(context).colorScheme.primary,
  ),
];

LinearGradient brandGradient(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(primary, Colors.white, .28)!,
      primary,
      Color.lerp(primary, Colors.black, .22)!,
    ],
  );
}

LinearGradient appBackgroundGradient(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [
            AppColors.black,
            AppColors.backgroundDarkMiddle,
            AppColors.black,
          ]
        : const [
            AppColors.backgroundStart,
            AppColors.backgroundMiddle,
            AppColors.backgroundEnd,
          ],
  );
}

String money(BuildContext context, int minor) => NumberFormat.currency(
  locale: Localizations.localeOf(context).toLanguageTag(),
  symbol:
      (Theme.of(context).extension<AppCurrency>() ?? const AppCurrency('THB'))
          .symbol,
  decimalDigits: 2,
).format(minor / 100);

String monthLabel(BuildContext context, DateTime date) => DateFormat.yMMMM(
  Localizations.localeOf(context).toLanguageTag(),
).format(date);

String dateLabel(BuildContext context, DateTime date) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date);

String categoryLabel(BuildContext context, Category? category) {
  if (category?.type == investmentTransfer)
    return context.l10n.t('investments');
  if (category == null) return context.l10n.category('other');
  const legacy = <String, String>{
    'เงินเดือน': 'salary',
    'รายรับอื่น ๆ': 'other_income',
    'อาหารและเครื่องดื่ม': 'food',
    'เดินทาง': 'travel',
    'ที่พัก': 'housing',
    'ช้อปปิ้ง': 'shopping',
    'บันเทิง': 'entertainment',
    'อื่น ๆ': 'other',
  };
  final key = legacy[category.name] ?? category.name;
  final translated = context.l10n.category(key);
  return translated == 'category_$key' ? category.name : translated;
}

class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageTitle(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: muted)),
    ],
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.gradient,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Theme.of(context).cardColor) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

class MonthButton extends ConsumerWidget {
  const MonthButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStoreProvider);
    final store = ref.read(appStoreProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => store.changeMonth(
              DateTime(store.selectedMonth.year, store.selectedMonth.month - 1),
            ),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final selected = await _showMonthPicker(
                  context,
                  store.selectedMonth,
                );
                if (selected != null) await store.changeMonth(selected);
              },
              child: Text(
                monthLabel(context, store.selectedMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            onPressed: () => store.changeMonth(
              DateTime(store.selectedMonth.year, store.selectedMonth.month + 1),
            ),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _showMonthPicker(
  BuildContext context,
  DateTime initial,
) async {
  var selectedYear = initial.year;
  var selectedMonth = initial.month;
  var choosingYear = false;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SizedBox(
          height: 500,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Column(
              children: [
                Text(
                  context.l10n.t('select_month'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: selectedYear > 2000
                          ? () => setSheetState(() => selectedYear--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () =>
                            setSheetState(() => choosingYear = !choosingYear),
                        iconAlignment: IconAlignment.end,
                        icon: Icon(
                          choosingYear ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(
                          DateFormat.y(locale).format(DateTime(selectedYear)),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: selectedYear < 2100
                          ? () => setSheetState(() => selectedYear++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, .06),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: choosingYear
                        ? YearPicker(
                            key: const ValueKey('years'),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            selectedDate: DateTime(selectedYear),
                            onChanged: (value) => setSheetState(() {
                              selectedYear = value.year;
                              choosingYear = false;
                            }),
                          )
                        : GridView.builder(
                            key: const ValueKey('months'),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              final month = index + 1;
                              final selected = month == selectedMonth;
                              final scheme = Theme.of(context).colorScheme;
                              return ChoiceChip(
                                showCheckmark: false,
                                selected: selected,
                                selectedColor: scheme.primary,
                                side: BorderSide(
                                  color: selected
                                      ? scheme.primary
                                      : Theme.of(context).dividerColor,
                                ),
                                label: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    DateFormat.MMM(
                                      locale,
                                    ).format(DateTime(2020, month)),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                onSelected: (_) =>
                                    setSheetState(() => selectedMonth = month),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(context.l10n.t('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          DateTime(selectedYear, selectedMonth),
                        ),
                        child: Text(context.l10n.t('select')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TransactionTile extends ConsumerWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDuplicate;
  const TransactionTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStoreProvider);
    final store = ref.read(appStoreProvider.notifier);
    final isInvestment = entry.type == investmentTransfer;
    final fundingAccount = store.accounts
        .where((a) => a.id == entry.accountId)
        .firstOrNull;
    final accountName = fundingAccount?.name == 'cash'
        ? context.l10n.t('cash')
        : fundingAccount?.name;
    final amountColor = isInvestment
        ? AppColors.investment
        : entry.type == income
        ? brandGreen
        : expenseRed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isInvestment
            ? AppColors.investment.withValues(alpha: .15)
            : entry.type == income
            ? AppColors.incomeContainer
            : AppColors.expenseContainer,
        child: Icon(
          isInvestment
              ? Icons.account_balance_outlined
              : entry.type == income
              ? LucideIcons.arrowDownLeft
              : LucideIcons.arrowUpRight,
          color: amountColor,
        ),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${categoryLabel(context, store.categoryFor(entry.categoryId))}${isInvestment && accountName != null ? ' · $accountName' : ''} · ${dateLabel(context, entry.date)}',
      ),
      trailing: Text(
        '${entry.type == income ? '+' : '−'}${money(context, entry.amountMinor)}',
        style: TextStyle(fontWeight: FontWeight.w600, color: amountColor),
      ),
      onTap: onTap,
      onLongPress: onDuplicate,
    );
  }
}
