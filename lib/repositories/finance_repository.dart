import 'package:sqflite/sqflite.dart';

import '../models/finance_models.dart';
import '../models/investment.dart';
import '../models/investment_entry.dart';
import '../database/investment_schema.dart';

class FinanceRepository {
  final Database db;
  const FinanceRepository(this.db);
  Future<List<InvestmentEntry>> investmentEntries() async => (await db.query(
    'investment_entries',
    orderBy: 'transaction_date DESC, created_at DESC, id DESC',
  )).map(InvestmentEntry.fromMap).toList();
  Future<List<Investment>> investments() async {
    final funds = await db.query(
      'investments',
      orderBy: 'valued_at DESC, id DESC',
    );
    final entries = await investmentEntries();
    return funds.map((row) {
      final history = entries.where((e) => e.fundId == row['id']).toList();
      final valuation = history.where((e) => !e.contributionOnly).firstOrNull;
      final subsequentDeposits = valuation == null
          ? history
          : history.where((e) => e.createdAt > valuation.createdAt);
      final current =
          (valuation?.currentMinor ?? row['current_minor'] as int) +
          subsequentDeposits
              .where((e) => e.contributionOnly)
              .fold<int>(0, (s, e) => s + e.amountMinor);
      return Investment.fromMap({
        ...row,
        'invested_minor':
            (row['invested_minor'] as int) +
            history.fold<int>(0, (s, e) => s + e.amountMinor),
        'current_minor': current,
        if (history.isNotEmpty)
          'valued_at': history.first.toMap()['transaction_date'],
      });
    }).toList();
  }

  Future<void> saveFund(Investment value) async {
    value.validate();
    if (value.id == null) {
      await saveInvestment(
        Investment(
          name: value.name,
          currencyCode: value.currencyCode,
          investedMinor: 0,
          currentMinor: 0,
          valuedAt: value.valuedAt,
          note: value.note,
        ),
      );
    } else {
      final changed = await db.update(
        'investments',
        {'name': value.name.trim(), 'note': value.note.trim()},
        where: 'id=? AND currency_code=?',
        whereArgs: [value.id, value.currencyCode],
      );
      if (changed != 1) throw StateError('Fund not found or currency changed');
    }
  }

  Future<void> addInvestmentEntry(InvestmentEntry entry) async {
    entry.validate();
    await db.transaction((txn) async {
      await ensureInvestmentEntryColumns(txn);
      if (entry.accountId == null)
        throw ArgumentError('Select a funding account');
      final accounts = await txn.query(
        'accounts',
        where: 'id=? AND is_active=1',
        whereArgs: [entry.accountId],
      );
      if (accounts.isEmpty) throw StateError('Funding account not available');
      final funds = await txn.query(
        'investments',
        where: 'id=?',
        whereArgs: [entry.fundId],
      );
      if (funds.isEmpty) throw StateError('Fund not found');
      if (entry.id == null) {
        await txn.insert('investment_entries', entry.toMap());
      } else {
        final original = await txn.query(
          'investment_entries',
          where: 'id=?',
          whereArgs: [entry.id],
        );
        if (original.isEmpty || original.single['fund_id'] != entry.fundId)
          throw StateError('Investment entry not found or fund changed');
        final data = entry.toMap();
        data['created_at'] = original.single['created_at'];
        data['current_minor'] = original.single['current_minor'];
        data['contribution_only'] = original.single['contribution_only'];
        await txn.update(
          'investment_entries',
          data,
          where: 'id=?',
          whereArgs: [entry.id],
        );
      }
    });
  }

  Future<void> deleteInvestmentEntry(int id) async {
    final deleted = await db.delete(
      'investment_entries',
      where: 'id=?',
      whereArgs: [id],
    );
    if (deleted != 1) throw StateError('Investment entry not found');
  }

  Future<void> saveInvestment(Investment value) async {
    value.validate();
    if (value.id == null) {
      await db.insert('investments', value.toMap());
    } else {
      final changed = await db.update(
        'investments',
        value.toMap(),
        where: 'id=?',
        whereArgs: [value.id],
      );
      if (changed != 1) throw StateError('Investment not found');
    }
  }

  Future<void> deleteInvestment(int id) async {
    final funded = await db.query(
      'investment_entries',
      where: 'fund_id=? AND account_id IS NOT NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (funded.isNotEmpty) throw StateError('Fund has cash contributions');
    await db.delete('investments', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Category>> categories() async => (await db.query(
    'categories',
    where: 'is_active = 1',
    orderBy: 'sort_order ASC, id ASC',
  )).map(Category.fromMap).toList();

  Future<List<Entry>> entries() async {
    final cash = (await db.query('transactions')).map(Entry.fromMap).toList();
    final funds = {for (final fund in await investments()) fund.id: fund};
    for (final deposit in await investmentEntries()) {
      // One persisted contribution drives both the portfolio and its cash debit.
      // Older contributions without an account remain manual snapshots.
      if (deposit.accountId == null) continue;
      cash.add(
        Entry(
          id: -deposit.id!,
          title: funds[deposit.fundId]!.name,
          amountMinor: deposit.amountMinor,
          type: investmentTransfer,
          categoryId: -1,
          accountId: deposit.accountId!,
          date: deposit.date,
          note: deposit.note,
          createdAt: deposit.createdAt,
        ),
      );
    }
    cash.sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date == 0 ? b.createdAt.compareTo(a.createdAt) : date;
    });
    return cash;
  }

  Future<List<Account>> accounts() async => (await db.query(
    'accounts',
    where: 'is_active = 1',
    orderBy: 'id ASC',
  )).map(Account.fromMap).toList();
  Future<List<Budget>> budgets() async =>
      (await db.query('budgets')).map(Budget.fromMap).toList();
  Future<List<RecurringRule>> recurringRules() async => (await db.query(
    'recurring_rules',
    orderBy: 'day_of_month ASC',
  )).map(RecurringRule.fromMap).toList();
  Future<List<SavingGoal>> savingGoals() async => (await db.query(
    'saving_goals',
    orderBy: 'id DESC',
  )).map(SavingGoal.fromMap).toList();
  Future<List<BillReminder>> billReminders() async => (await db.query(
    'bill_reminders',
    orderBy: 'day_of_month ASC',
  )).map(BillReminder.fromMap).toList();

  Future<Map<String, String>> settings() async => {
    for (final row in await db.query('settings'))
      row['key'] as String: row['value'] as String,
  };

  Future<void> completeOnboarding(String name) async {
    await db.transaction((txn) async {
      for (final entry in {
        'local_name': name,
        'onboarding_completed': '1',
      }.entries) {
        await txn.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> save(Entry entry) async {
    if (entry.id == null) {
      await db.insert('transactions', entry.toMap());
    } else {
      await db.update(
        'transactions',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
  }

  Future<void> saveAll(List<Entry> entries) async {
    await db.transaction((txn) async {
      for (final entry in entries) {
        await txn.insert('transactions', entry.toMap());
      }
    });
  }

  Future<void> delete(int id) =>
      db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  Future<void> saveCategory(Category value) async {
    if (value.id <= 0) {
      await db.insert('categories', value.toMap());
    } else {
      await db.update(
        'categories',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
    }
  }

  Future<void> saveAccount(Account value) async {
    if (value.id == null)
      await db.insert('accounts', value.toMap());
    else
      await db.update(
        'accounts',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
  }

  Future<void> saveBudget(Budget value) async {
    if (value.id == null)
      await db.insert(
        'budgets',
        value.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    else
      await db.update(
        'budgets',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
  }

  Future<void> saveRecurringRule(RecurringRule value) async {
    if (value.id == null)
      await db.insert('recurring_rules', value.toMap());
    else
      await db.update(
        'recurring_rules',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
  }

  Future<void> recordRecurringOccurrence(
    RecurringRule rule,
    Entry entry,
    String monthKey,
  ) async {
    await db.transaction((txn) async {
      final identity = await txn.query(
        'sync_records',
        where: "table_name='recurring_rules' AND local_id=?",
        whereArgs: [rule.id],
      );
      final occurrenceId = identity.isEmpty
          ? null
          : 'occurrence_${identity.single['entity_id']}_$monthKey';
      final exists = occurrenceId == null
          ? <Map<String, Object?>>[]
          : await txn.query(
              'sync_records',
              where: 'entity_id=?',
              whereArgs: [occurrenceId],
            );
      if (exists.isEmpty) {
        final entryId = await txn.insert('transactions', entry.toMap());
        if (occurrenceId != null) {
          await txn.update(
            'sync_records',
            {'entity_id': occurrenceId},
            where: "table_name='transactions' AND local_id=?",
            whereArgs: [entryId],
          );
        }
      }
      await txn.rawUpdate(
        "UPDATE recurring_rules SET last_generated_month=MAX(last_generated_month,?) WHERE id=?",
        [monthKey, rule.id],
      );
    });
  }

  Future<void> saveGoal(SavingGoal value) async {
    if (value.id == null)
      await db.insert('saving_goals', value.toMap());
    else
      await db.update(
        'saving_goals',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
  }

  Future<void> saveReminder(BillReminder value) async {
    if (value.id == null)
      await db.insert('bill_reminders', value.toMap());
    else
      await db.update(
        'bill_reminders',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [value.id],
      );
  }

  Future<void> removePlannerItem(String table, int id) async {
    const allowed = {
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'investments',
    };
    if (!allowed.contains(table)) throw ArgumentError.value(table, 'table');
    final deleted = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    if (deleted == 0) throw StateError('Planner item not found');
  }

  Future<void> deactivateAccount(int id) async {
    final updated = await db.update(
      'accounts',
      {'is_active': 0},
      where: 'id = ? AND id != 1',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('Account not found or protected');
  }

  Future<void> transaction(Future<void> Function(Transaction txn) action) =>
      db.transaction(action);
  Future<List<Map<String, Object?>>> table(String name) => db.query(name);
  Future<void> replaceBackup(
    Map<String, List<Map<String, Object?>>> backup,
  ) async {
    for (final row
        in backup['investment_entries'] ?? const <Map<String, Object?>>[]) {
      InvestmentEntry.fromMap(row).validate();
    }
    for (final row in backup['investments'] ?? const <Map<String, Object?>>[]) {
      Investment.fromMap(row).validate();
    }
    const insertOrder = [
      'categories',
      'accounts',
      'transactions',
      'budgets',
      'recurring_rules',
      'saving_goals',
      'bill_reminders',
      'investments',
      'settings',
      'investment_entries',
    ];
    await db.transaction((txn) async {
      const deleteOrder = [
        'investment_entries',
        'transactions',
        'budgets',
        'recurring_rules',
        'saving_goals',
        'bill_reminders',
        'investments',
        'categories',
        'accounts',
        'settings',
      ];
      for (final name in deleteOrder) {
        await txn.delete(name);
      }
      for (final name in insertOrder) {
        for (final row in backup[name] ?? const <Map<String, Object?>>[]) {
          await txn.insert(
            name,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> clearEntries() => db.delete('transactions');
  Future<void> setting(String key, String value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
