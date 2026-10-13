import '../models/investment.dart';
import '../models/investment_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../auth/auth_providers.dart';
import '../sync/sync_local.dart';
import '../models/finance_models.dart';
import '../currency/app_currency.dart';
import '../repositories/finance_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final accountDatabaseProvider = Provider.family<AppDatabase, String>((
  ref,
  uid,
) {
  final database = AppDatabase(accountId: uid);
  ref.onDispose(database.close);
  return database;
});

class FinanceChanges extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final financeChangesProvider = NotifierProvider<FinanceChanges, int>(
  FinanceChanges.new,
);

final appStoreProvider = NotifierProvider<AppStore, AppState>(AppStore.new);

final appStartupProvider = FutureProvider<void>((ref) async {
  String? uid;
  try {
    uid = await ref.watch(
      authSessionProvider.selectAsync((account) => account?.id),
    );
  } catch (_) {
    // Missing account services must not prevent using the local profile.
  }
  if (!ref.mounted) return;
  await ref.read(appStoreProvider.notifier).open(accountId: uid);
}, retry: (retryCount, error) => null);

class AppStore extends Notifier<AppState> {
  late AppDatabase database;
  FinanceRepository? _repository;
  FinanceRepository? _deviceRepository;
  String? activeAccountId;
  int _openGeneration = 0;

  @override
  AppState build() {
    database = ref.read(appDatabaseProvider);
    return AppState();
  }

  List<Investment> get investments => state.investments;
  List<InvestmentEntry> get investmentEntries => state.investmentEntries;
  Future<void> saveFund(Investment value) async {
    final generation = _openGeneration;
    await _repository!.saveFund(value);
    if (ref.mounted && generation == _openGeneration) await refresh();
  }

  Future<void> addInvestmentEntry(InvestmentEntry value) async {
    final generation = _openGeneration;
    await _repository!.addInvestmentEntry(value);
    if (ref.mounted && generation == _openGeneration) await refresh();
  }

  Future<void> deleteInvestmentEntry(int id) async {
    final generation = _openGeneration;
    await _repository!.deleteInvestmentEntry(id);
    if (ref.mounted && generation == _openGeneration) await refresh();
  }

  Future<void> saveInvestment(Investment value) async {
    final generation = _openGeneration;
    await _repository!.saveInvestment(value);
    if (ref.mounted && generation == _openGeneration) await refresh();
  }

  Future<void> deleteInvestment(int id) async {
    final generation = _openGeneration;
    await _repository!.deleteInvestment(id);
    if (ref.mounted && generation == _openGeneration) await refresh();
  }

  List<Entry> get entries => state.entries;
  List<Category> get categories => state.categories;
  List<Account> get accounts => state.accounts;
  List<Budget> get budgets => state.budgets;
  List<RecurringRule> get recurringRules => state.recurringRules;
  List<SavingGoal> get savingGoals => state.savingGoals;
  List<BillReminder> get billReminders => state.billReminders;
  DateTime get selectedMonth => state.selectedMonth;
  bool get darkMode => state.darkMode;
  String get languageCode => state.languageCode;
  String get themeColor => state.themeColor;
  String get currencyCode => state.currencyCode;
  bool get hideBalances => state.hideBalances;
  bool get remindersEnabled => state.remindersEnabled;
  String get pinHash => state.pinHash;

  Future<void> open({String? accountId}) async {
    final generation = ++_openGeneration;
    final guest = ref.read(appDatabaseProvider);
    final guestDb = await guest.open();
    final target = accountId == null
        ? guest
        : ref.read(accountDatabaseProvider(accountId));
    final financeDb = accountId == null ? guestDb : await target.open();
    if (accountId != null)
      await SyncLocal.importGuest(guestDb, financeDb, accountId);
    if (!ref.mounted || generation != _openGeneration) return;
    database = target;
    activeAccountId = accountId;
    _repository = FinanceRepository(financeDb);
    _deviceRepository = FinanceRepository(guestDb);
    final values = await _deviceRepository!.settings();
    if (!ref.mounted || generation != _openGeneration) return;
    const themeColors = {'teal', 'blue', 'purple', 'orange', 'rose'};
    final parsed = DateTime.tryParse(values['selected_month'] ?? '');
    if (!ref.mounted) return;
    state = state.copyWith(
      darkMode: values['theme_mode'] == 'dark' || values['dark_mode'] == '1',
      languageCode: values['language_code'] == 'en' ? 'en' : 'th',
      themeColor: themeColors.contains(values['theme_color'])
          ? values['theme_color']!
          : 'teal',
      currencyCode: currencySymbols.containsKey(values['currency_code'])
          ? values['currency_code']!
          : 'THB',
      hideBalances: values['hide_balances'] == '1',
      remindersEnabled: values['reminders_enabled'] != '0',
      pinHash: values['pin_hash'] ?? '',
      onboardingCompleted: values['onboarding_completed'] == '1',
      localName: values['local_name'] ?? '',
      selectedMonth: parsed == null
          ? selectedMonth
          : DateTime(parsed.year, parsed.month),
    );
    await refresh();
    if (!ref.mounted || generation != _openGeneration) return;
    await _generateAutomaticRecurringThrough(DateTime.now());
  }

  Future<void> completeOnboarding({String? localName}) async {
    final name = localName?.trim() ?? '';
    if (localName != null && (name.isEmpty || name.characters.length > 50)) {
      throw ArgumentError('A local name must contain 1 to 50 characters');
    }
    await _deviceRepository!.completeOnboarding(name);
    if (ref.mounted) {
      state = state.copyWith(onboardingCompleted: true, localName: name);
    }
  }

  /// Only the first connection adopts the profile created offline.
  Future<String?> localProfileNameForLink() async {
    if (!state.onboardingCompleted || state.localName.trim().isEmpty)
      return null;
    final settings = await _deviceRepository!.settings();
    return settings['google_profile_linked'] == '1'
        ? null
        : state.localName.trim();
  }

  Future<void> completeLocalProfileLink() =>
      _deviceRepository!.setting('google_profile_linked', '1');

  Future<void> catchUpRecurring() =>
      _generateAutomaticRecurringThrough(DateTime.now());

  Future<void> refresh({bool notifySync = true}) async {
    final generation = _openGeneration;
    final values = await Future.wait([
      _repository!.categories(),
      _repository!.entries(),
      _repository!.accounts(),
      _repository!.budgets(),
      _repository!.recurringRules(),
      _repository!.savingGoals(),
      _repository!.billReminders(),
      _repository!.investments(),
      _repository!.investmentEntries(),
    ]);
    if (!ref.mounted) return;
    if (generation != _openGeneration) return;
    state = state.copyWith(
      categories: values[0] as List<Category>,
      entries: values[1] as List<Entry>,
      accounts: values[2] as List<Account>,
      budgets: values[3] as List<Budget>,
      recurringRules: values[4] as List<RecurringRule>,
      savingGoals: values[5] as List<SavingGoal>,
      billReminders: values[6] as List<BillReminder>,
      investments: values[7] as List<Investment>,
      investmentEntries: values[8] as List<InvestmentEntry>,
    );
    if (notifySync) ref.read(financeChangesProvider.notifier).changed();
  }

  List<Entry> get monthlyEntries =>
      entries.where((e) => sameMonth(e.date, selectedMonth)).toList();
  int get monthlyIncome => sumType(monthlyEntries, income);
  int get monthlyExpense => sumType(monthlyEntries, expense);
  int get monthlyInvestment => sumType(monthlyEntries, investmentTransfer);
  int get investmentFundCount =>
      investments.where((f) => f.currencyCode == currencyCode).length;
  int get selectedMonthInvested {
    final funds = investments
        .where((f) => f.currencyCode == currencyCode)
        .map((f) => f.id)
        .toSet();
    return investmentEntries
        .where(
          (e) => funds.contains(e.fundId) && sameMonth(e.date, selectedMonth),
        )
        .fold<int>(0, (sum, e) => sum + e.amountMinor);
  }

  int get monthlyBalance => monthlyIncome - monthlyExpense - monthlyInvestment;
  String get selectedMonthKey =>
      '${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}';
  List<Budget> get monthlyBudgets =>
      budgets.where((b) => b.month == selectedMonthKey).toList();
  int get monthlyBudget => monthlyBudgets
      .where((b) => b.categoryId == null)
      .fold(0, (sum, b) => sum + b.amountMinor);
  int spentForBudget(Budget budget) => monthlyEntries
      .where(
        (e) =>
            e.type == expense &&
            (budget.categoryId == null || e.categoryId == budget.categoryId),
      )
      .fold(0, (sum, e) => sum + e.amountMinor);
  Account? accountFor(int id) {
    for (final value in accounts) {
      if (value.id == id) return value;
    }
    return null;
  }

  int accountBalance(Account account) =>
      account.openingBalanceMinor +
      entries
          .where((e) => e.accountId == account.id)
          .fold(
            0,
            (sum, e) =>
                sum + (e.type == income ? e.amountMinor : -e.amountMinor),
          );
  Category? categoryFor(int id) {
    if (id == -1)
      return const Category(
        -1,
        'investments',
        investmentTransfer,
        'investment',
        colorValue: 0xFFF2B300,
      );
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> save(Entry entry) async {
    if (entry.amountMinor <= 0 ||
        entry.title.trim().isEmpty ||
        !categories.any(
          (c) => c.id == entry.categoryId && c.type == entry.type,
        )) {
      throw ArgumentError('Invalid transaction');
    }
    await _repository!.save(entry);
    await refresh();
  }

  Future<void> saveMonthlyEntries(
    Entry template,
    DateTime startMonth,
    int numberOfMonths,
  ) async {
    await _repository!.saveAll(
      buildMonthlyEntries(template, startMonth, numberOfMonths),
    );
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repository!.delete(id);
    await refresh();
  }

  Future<void> changeMonth(DateTime date) async {
    final next = DateTime(date.year, date.month);
    await _deviceRepository!.setting('selected_month', next.toIso8601String());
    if (ref.mounted) state = state.copyWith(selectedMonth: next);
  }

  Future<void> setDarkMode(bool value) async {
    final next = value;
    await _deviceRepository!.setting('theme_mode', next ? 'dark' : 'light');
    if (ref.mounted) state = state.copyWith(darkMode: next);
  }

  Future<void> setThemeColor(String value) async {
    const supported = {'teal', 'blue', 'purple', 'orange', 'rose'};
    if (!supported.contains(value)) return;
    final next = value;
    await _deviceRepository!.setting('theme_color', next);
    if (ref.mounted) state = state.copyWith(themeColor: next);
  }

  Future<void> setLanguage(String code) async {
    final next = code == 'en' ? 'en' : 'th';
    await _deviceRepository!.setting('language_code', next);
    if (ref.mounted) state = state.copyWith(languageCode: next);
  }

  Future<void> setCurrency(String code) async {
    if (!currencySymbols.containsKey(code)) return;
    await _deviceRepository!.setting('currency_code', code);
    if (ref.mounted) state = state.copyWith(currencyCode: code);
  }

  Future<void> setHideBalances(bool value) async {
    final next = value;
    await _deviceRepository!.setting('hide_balances', next ? '1' : '0');
    if (ref.mounted) state = state.copyWith(hideBalances: next);
  }

  Future<void> setRemindersEnabled(bool value) async {
    final next = value;
    await _deviceRepository!.setting('reminders_enabled', next ? '1' : '0');
    if (ref.mounted) state = state.copyWith(remindersEnabled: next);
  }

  bool verifyPin(String value) =>
      pinHash.isNotEmpty &&
      sha256.convert(utf8.encode(value)).toString() == pinHash;

  Future<void> setPin(String value) async {
    final next = value.isEmpty
        ? ''
        : sha256.convert(utf8.encode(value)).toString();
    await _deviceRepository!.setting('pin_hash', next);
    if (ref.mounted) state = state.copyWith(pinHash: next);
  }

  Future<void> saveCategory(Category value) async {
    await _repository!.saveCategory(value);
    await refresh();
  }

  Future<void> saveAccount(Account value) async {
    await _repository!.saveAccount(value);
    await refresh();
  }

  Future<void> saveBudget(Budget value) async {
    await _repository!.saveBudget(value);
    await refresh();
  }

  Future<void> saveRecurringRule(RecurringRule value) async {
    await _repository!.saveRecurringRule(value);
    await refresh();
  }

  Future<void> saveIndefiniteMonthlyEntry(
    Entry template,
    DateTime startMonth,
  ) async {
    final key = _monthKey(startMonth);
    await _repository!.saveRecurringRule(
      RecurringRule(
        title: template.title,
        amountMinor: template.amountMinor,
        type: template.type,
        categoryId: template.categoryId,
        accountId: template.accountId,
        dayOfMonth: template.date.day,
        note: template.note,
        startMonth: key,
      ),
    );
    await refresh();
    await _generateAutomaticRecurringThrough(DateTime.now());
  }

  Future<void> saveGoal(SavingGoal value) async {
    await _repository!.saveGoal(value);
    await refresh();
  }

  Future<void> saveReminder(BillReminder value) async {
    await _repository!.saveReminder(value);
    await refresh();
  }

  Future<void> removePlannerItem(String table, int id) async {
    await _repository!.removePlannerItem(table, id);
    await refresh();
  }

  Future<void> removeAccount(int id) async {
    await _repository!.deactivateAccount(id);
    await refresh();
  }

  Future<void> generateRecurringForMonth(DateTime month) async {
    final repository = _repository!;
    final generation = _openGeneration;
    final key = _monthKey(month);
    for (final rule in recurringRules.where(
      (r) =>
          r.isActive &&
          r.lastGeneratedMonth != key &&
          (r.startMonth.isEmpty || key.compareTo(r.startMonth) >= 0) &&
          (r.lastGeneratedMonth.isEmpty ||
              key.compareTo(r.lastGeneratedMonth) > 0),
    )) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final now = DateTime.now().microsecondsSinceEpoch;
      final entry = Entry(
        title: rule.title,
        amountMinor: rule.amountMinor,
        type: rule.type,
        categoryId: rule.categoryId,
        accountId: rule.accountId,
        date: DateTime(
          month.year,
          month.month,
          rule.dayOfMonth.clamp(1, lastDay),
        ),
        note: rule.note,
        createdAt: now,
      );
      await repository.recordRecurringOccurrence(rule, entry, key);
      if (!ref.mounted || generation != _openGeneration) return;
    }
    await refresh();
  }

  String _monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

  DateTime? _parseMonth(String value) {
    final parsed = DateTime.tryParse('$value-01');
    return parsed == null ? null : DateTime(parsed.year, parsed.month);
  }

  Future<void> _generateAutomaticRecurringThrough(DateTime target) async {
    final repository = _repository!;
    final generation = _openGeneration;
    var generated = false;
    for (final initialRule in recurringRules.where(
      (rule) => rule.isActive && rule.startMonth.isNotEmpty,
    )) {
      var rule = initialRule;
      final start = _parseMonth(rule.startMonth);
      if (start == null) continue;
      final last = _parseMonth(rule.lastGeneratedMonth);
      var month = last == null ? start : DateTime(last.year, last.month + 1);
      final end = DateTime(target.year, target.month);
      while (!month.isAfter(end)) {
        final key = _monthKey(month);
        final lastDay = DateTime(month.year, month.month + 1, 0).day;
        final now = DateTime.now().microsecondsSinceEpoch;
        final entry = Entry(
          title: rule.title,
          amountMinor: rule.amountMinor,
          type: rule.type,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          date: DateTime(
            month.year,
            month.month,
            rule.dayOfMonth.clamp(1, lastDay),
          ),
          note: rule.note,
          createdAt: now,
        );
        await repository.recordRecurringOccurrence(rule, entry, key);
        if (!ref.mounted || generation != _openGeneration) return;
        rule = RecurringRule(
          id: rule.id,
          title: rule.title,
          amountMinor: rule.amountMinor,
          type: rule.type,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          dayOfMonth: rule.dayOfMonth,
          note: rule.note,
          isActive: rule.isActive,
          lastGeneratedMonth: key,
          startMonth: rule.startMonth,
        );
        generated = true;
        month = DateTime(month.year, month.month + 1);
      }
    }
    if (generated) await refresh();
  }

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) async {
    final repository = _repository!;
    final generation = _openGeneration;
    if (fromAccountId == toAccountId || amountMinor <= 0)
      throw ArgumentError('Invalid transfer');
    final expenseCategory = categories.firstWhere((c) => c.type == expense);
    final incomeCategory = categories.firstWhere((c) => c.type == income);
    final now = DateTime.now().microsecondsSinceEpoch;
    await repository.save(
      Entry(
        title: 'Transfer out',
        amountMinor: amountMinor,
        type: expense,
        categoryId: expenseCategory.id,
        accountId: fromAccountId,
        date: date,
        note: note,
        createdAt: now,
      ),
    );
    await repository.save(
      Entry(
        title: 'Transfer in',
        amountMinor: amountMinor,
        type: income,
        categoryId: incomeCategory.id,
        accountId: toAccountId,
        date: date,
        note: note,
        createdAt: now + 1,
      ),
    );
    if (generation == _openGeneration) await refresh();
  }

  Future<void> clearEntries() async {
    await _repository!.clearEntries();
    await refresh();
  }

  String exportCsv() {
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    return [
      'date,type,category,title,amount_thb,note',
      for (final entry in entries)
        [
          entry.date.toIso8601String().substring(0, 10),
          entry.type,
          categoryFor(entry.categoryId)?.name ?? '',
          entry.title,
          (entry.amountMinor / 100).toStringAsFixed(2),
          entry.note,
        ].map(quote).join(','),
    ].join('\r\n');
  }

  Future<String> exportBackupJson() async {
    final repository = _repository!;

    const tables = [
      'transactions',
      'categories',
      'accounts',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'investments',
      'investment_entries',
      'settings',
    ];
    final payload = <String, Object?>{
      'format': 'monthly-flow-backup',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
    };
    for (final table in tables) {
      payload[table] =
          await (table == 'settings' ? _deviceRepository! : repository).table(
            table,
          );
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importBackupJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['format'] != 'monthly-flow-backup') {
      throw const FormatException('Invalid backup');
    }
    const tables = [
      'transactions',
      'categories',
      'accounts',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'investments',
      'investment_entries',
      'settings',
    ];
    final backup = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      backup[table] = ((decoded[table] as List?) ?? const [])
          .map((row) => Map<String, Object?>.from(row as Map))
          .toList();
    }
    await _repository!.replaceBackup(backup);
    if (activeAccountId != null) {
      for (final setting in backup['settings'] ?? <Map<String, Object?>>[]) {
        await _deviceRepository!.setting(
          setting['key'] as String,
          setting['value'] as String,
        );
      }
    }
    await open(accountId: activeAccountId);
  }
}
