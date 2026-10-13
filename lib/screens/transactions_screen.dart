import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import 'entry_form_screen.dart';
import 'investment_entry_sheet.dart';
import '../models/finance_models.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  AppStore get store => ref.read(appStoreProvider.notifier);
  String filter = 'all';
  String search = '';
  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    final query = search.trim().toLowerCase();
    final rows = store.monthlyEntries.where((entry) {
      if (filter == 'favorite' && !entry.isFavorite) return false;
      if (filter != 'all' && filter != 'favorite' && entry.type != filter)
        return false;
      final category = categoryLabel(
        context,
        store.categoryFor(entry.categoryId),
      );
      return query.isEmpty ||
          '${entry.title} ${entry.note} $category'.toLowerCase().contains(
            query,
          );
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
      children: [
        PageTitle(
          context.l10n.t('transactions'),
          context.l10n.t('search_subtitle'),
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(LucideIcons.search),
            hintText: context.l10n.t('search'),
          ),
        ),
        const SizedBox(height: 10),
        AppSegmentedControl(
          value: filter,
          segments: [
            AppSegment('all', context.l10n.t('all'), Icons.list),
            ...transactionTypeSegments(context).reversed,
            AppSegment(
              investmentTransfer,
              context.l10n.t('investments'),
              Icons.account_balance_outlined,
              color: AppColors.investment,
            ),
            AppSegment(
              'favorite',
              context.l10n.t('favorite'),
              Icons.star_outline,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          onChanged: (value) => setState(() => filter = value),
        ),
        MonthButton(),
        if (rows.isEmpty)
          Surface(
            child: Text(
              context.l10n.t('not_found'),
              style: const TextStyle(color: muted),
            ),
          )
        else
          Surface(
            child: Column(
              children: [
                for (final entry in rows)
                  TransactionTile(
                    entry: entry,
                    onTap: () {
                      if (entry.type == investmentTransfer) {
                        final deposit = store.investmentEntries
                            .where((v) => v.id == -entry.id!)
                            .firstOrNull;
                        if (deposit != null)
                          openInvestmentEntryEditor(context, deposit);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => EntryFormScreen(existing: entry),
                          ),
                        );
                      }
                    },
                    onDuplicate: entry.type == investmentTransfer
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => EntryFormScreen(initial: entry),
                            ),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
