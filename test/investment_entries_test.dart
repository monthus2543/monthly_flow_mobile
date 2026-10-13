import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monthly_flow/database/app_database.dart';
import 'package:monthly_flow/models/investment.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/models/investment_entry.dart';
import 'package:monthly_flow/repositories/finance_repository.dart';
import 'package:monthly_flow/sync/sync_local.dart';
import 'package:monthly_flow/export/excel_report.dart';
import 'package:excel_plus/excel_plus.dart';
import 'support/memory_sync_remote.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monthly_flow/state/app_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'corrections update the same synced deposit and reverse the old debit',
    () async {
      final folder = await Directory.systemTemp.createTemp('fund-correction');
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase(accountId: 'a'), b = AppDatabase(accountId: 'b');
      final da = await a.open(), db = await b.open();
      final ra = FinanceRepository(da),
          rb = FinanceRepository(db),
          remote = MemorySyncRemote();
      addTearDown(() async {
        await a.close();
        await b.close();
        await remote.dispose();
        await folder.delete(recursive: true);
      });
      Future<void> send(Database db) async {
        final local = SyncLocal(db);
        await local.apply(await remote.read('owner'));
        for (final change in await local.pending()) {
          final saved = await remote.write('owner', change);
          await local.acknowledge(change);
          await local.apply([saved]);
        }
      }

      await ra.saveAccount(
        const Account(name: 'Bank', openingBalanceMinor: 200000),
      );
      final bank = (await ra.accounts()).last;
      await ra.saveFund(
        Investment(
          name: 'Fund',
          investedMinor: 0,
          currentMinor: 0,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 9),
        ),
      );
      final fund = (await ra.investments()).single;
      await ra.addInvestmentEntry(
        InvestmentEntry(
          fundId: fund.id!,
          accountId: 1,
          amountMinor: 10000,
          currentMinor: 0,
          contributionOnly: true,
          date: DateTime(2026, 9, 20),
          createdAt: 1,
        ),
      );
      await send(da);
      await send(db);
      final old = (await ra.investmentEntries()).single;
      await ra.addInvestmentEntry(
        InvestmentEntry(
          id: old.id,
          fundId: old.fundId,
          accountId: bank.id,
          amountMinor: 7000,
          currentMinor: 0,
          contributionOnly: true,
          date: DateTime(2026, 10, 5),
          createdAt: 999,
          note: 'Corrected',
        ),
      );
      expect((await ra.investmentEntries()).single.id, old.id);
      expect((await ra.investmentEntries()).single.createdAt, 1);
      expect((await ra.entries()).single.accountId, bank.id);
      expect((await ra.entries()).single.date.month, 10);
      expect((await ra.entries()).where((e) => e.accountId == 1), isEmpty);
      await send(da);
      await send(db);
      expect((await rb.investments()).single.investedMinor, 7000);
      expect((await rb.investments()).single.currentMinor, 7000);
      expect(await rb.entries(), hasLength(1));
      expect((await rb.entries()).single.note, 'Corrected');
      expect(
        (await remote.read(
          'owner',
        )).where((r) => r.table == 'investment_entries'),
        hasLength(1),
      );
      await ra.deleteInvestmentEntry(old.id!);
      await send(da);
      await send(db);
      expect(await rb.entries(), isEmpty);
      expect((await rb.investments()).single.investedMinor, 0);
      expect((await rb.investments()).single.currentMinor, 0);
    },
  );
  test(
    'deposit debits only the selected account and dated month, exactly once',
    () async {
      final folder = await Directory.systemTemp.createTemp('fund-cash-debit');
      await databaseFactory.setDatabasesPath(folder.path);
      final database = AppDatabase();
      final db = await database.open();
      final repo = FinanceRepository(db);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
        await folder.delete(recursive: true);
      });
      await repo.saveAccount(
        const Account(name: 'Bank', openingBalanceMinor: 100000),
      );
      final bank = (await repo.accounts()).last;
      await repo.saveFund(
        Investment(
          name: 'Fund',
          investedMinor: 0,
          currentMinor: 0,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 9),
        ),
      );
      final fund = (await repo.investments()).single;
      await repo.addInvestmentEntry(
        InvestmentEntry(
          fundId: fund.id!,
          accountId: bank.id,
          amountMinor: 25000,
          currentMinor: 25000,
          date: DateTime(2026, 9, 20),
          createdAt: 1,
        ),
      );
      final store = container.read(appStoreProvider.notifier);
      await store.open();
      await store.changeMonth(DateTime(2026, 9));
      expect(store.accountBalance(bank), 75000);
      expect(store.accountBalance(store.accounts.first), 0);
      expect(store.monthlyIncome, 0);
      expect(store.monthlyExpense, 0);
      expect(store.monthlyInvestment, 25000);
      expect(store.investmentFundCount, 1);
      expect(store.selectedMonthInvested, 25000);
      expect(store.monthlyBalance, -25000);
      expect(store.monthlyEntries.single.type, investmentTransfer);
      final report = ExcelReportData(
        options: ReportOptions(
          years: [2026],
          selectedMonth: DateTime(2026, 9),
          includeCharts: false,
        ),
        entries: store.entries,
        categoryNames: {-1: 'ลงทุน'},
        accountNames: {bank.id!: 'Bank'},
        investments: store.investments,
        investmentEntries: store.investmentEntries,
      );
      expect(report.years.single.netMinor, -25000);
      final excel = Excel.decodeBytes(buildExcelReport(report));
      expect(
        excel.tables['2569']!.cell(CellIndex.indexByString('R18')).value,
        IntCellValue(250),
      );
      await store.refresh();
      expect(store.accountBalance(bank), 75000);
      await store.changeMonth(DateTime(2026, 10));
      expect(store.monthlyInvestment, 0);
      expect(store.selectedMonthInvested, 0);
      expect(store.accountBalance(bank), 75000);
      await expectLater(
        repo.addInvestmentEntry(
          InvestmentEntry(
            fundId: fund.id!,
            accountId: 999,
            amountMinor: 100,
            currentMinor: 25100,
            date: DateTime(2026, 10),
            createdAt: 2,
          ),
        ),
        throwsStateError,
      );
      expect(await repo.investmentEntries(), hasLength(1));
      expect(await db.query('transactions'), isEmpty);
    },
  );
  test(
    'automatic deposits preserve prior gain and sum across offline devices',
    () async {
      final folder = await Directory.systemTemp.createTemp('fund-auto-deposit');
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase(accountId: 'a'), b = AppDatabase(accountId: 'b');
      final da = await a.open(), db = await b.open();
      final ra = FinanceRepository(da),
          rb = FinanceRepository(db),
          remote = MemorySyncRemote();
      addTearDown(() async {
        await a.close();
        await b.close();
        await remote.dispose();
        await folder.delete(recursive: true);
      });
      Future<void> send(Database db) async {
        final local = SyncLocal(db);
        await local.apply(await remote.read('owner'));
        for (final change in await local.pending()) {
          final saved = await remote.write('owner', change);
          await local.acknowledge(change);
          await local.apply([saved]);
        }
      }

      await ra.saveInvestment(
        Investment(
          name: 'Fund',
          investedMinor: 10000,
          currentMinor: 12000,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 10),
        ),
      );
      await send(da);
      await send(db);
      final fa = (await ra.investments()).single,
          fb = (await rb.investments()).single;
      await ra.addInvestmentEntry(
        InvestmentEntry(
          fundId: fa.id!,
          accountId: 1,
          amountMinor: 3000,
          currentMinor: 0,
          contributionOnly: true,
          date: DateTime(2026, 10, 2),
          createdAt: 1,
        ),
      );
      await rb.addInvestmentEntry(
        InvestmentEntry(
          fundId: fb.id!,
          accountId: 1,
          amountMinor: 5000,
          currentMinor: 0,
          contributionOnly: true,
          date: DateTime(2026, 10, 3),
          createdAt: 2,
        ),
      );
      await send(da);
      await send(db);
      await send(da);
      for (final repo in [ra, rb]) {
        final fund = (await repo.investments()).single;
        expect(fund.currentMinor, 20000);
        expect(fund.investedMinor, 18000);
        expect(fund.gainMinor, 2000);
        expect(
          (await repo.entries()).fold<int>(0, (s, e) => s + e.amountMinor),
          8000,
        );
      }
    },
  );
  test(
    'fund metadata, backdated contributions, backup and offline sync retain investment history',
    () async {
      final folder = await Directory.systemTemp.createTemp('fund-entries');
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase(accountId: 'a'), b = AppDatabase(accountId: 'b');
      final dbA = await a.open(), dbB = await b.open();
      addTearDown(() async {
        await a.close();
        await b.close();
        await folder.delete(recursive: true);
      });
      final repo = FinanceRepository(dbA),
          repoB = FinanceRepository(dbB),
          remote = MemorySyncRemote();
      addTearDown(remote.dispose);
      Future<void> send(Database db) async {
        final local = SyncLocal(db);
        await local.apply(await remote.read('owner'));
        for (final change in await local.pending()) {
          final saved = await remote.write('owner', change);
          await local.acknowledge(change);
          await local.apply([saved]);
        }
      }

      await repo.saveFund(
        Investment(
          name: 'Fund',
          investedMinor: 0,
          currentMinor: 0,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 10, 13),
        ),
      );
      final fund = (await repo.investments()).single;
      expect(fund.investedMinor, 0);
      await send(dbA);
      await send(dbB);
      await repo.addInvestmentEntry(
        InvestmentEntry(
          accountId: 1,
          fundId: fund.id!,
          amountMinor: 10000,
          currentMinor: 11000,
          date: DateTime(2026, 10, 12),
          createdAt: 1,
        ),
      );
      final fundB = (await repoB.investments()).single;
      await repoB.addInvestmentEntry(
        InvestmentEntry(
          accountId: 1,
          fundId: fundB.id!,
          amountMinor: 20000,
          currentMinor: 32000,
          date: DateTime(2026, 10, 13),
          createdAt: 2,
        ),
      );
      await send(dbA);
      await send(dbB);
      await send(dbA);
      expect((await repo.investments()).single.investedMinor, 30000);
      expect((await repoB.investments()).single.currentMinor, 32000);
      await repo.addInvestmentEntry(
        InvestmentEntry(
          accountId: 1,
          fundId: fund.id!,
          amountMinor: 5000,
          currentMinor: 5000,
          date: DateTime(2026, 10, 1),
          createdAt: 3,
        ),
      );
      final total = (await repo.investments()).single;
      expect(total.currentMinor, 32000);
      expect(total.investedMinor, 35000);
      await repo.saveFund(
        Investment(
          id: total.id,
          name: 'Renamed',
          investedMinor: total.investedMinor,
          currentMinor: total.currentMinor,
          currencyCode: 'THB',
          valuedAt: total.valuedAt,
        ),
      );
      expect((await repo.investments()).single.investedMinor, 35000);
      expect(await repo.entries(), hasLength(3));
      expect(
        (await repo.entries()).every(
          (e) => e.type == investmentTransfer && e.accountId == 1,
        ),
        true,
      );
      expect(await repo.investmentEntries(), hasLength(3));
      final backup = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'categories',
        'accounts',
        'investments',
        'investment_entries',
      ]) {
        backup[table] = await repo.table(table);
      }
      await repo.replaceBackup(backup);
      expect((await repo.investments()).single.investedMinor, 35000);
      final wb = Excel.decodeBytes(
        buildExcelReport(
          ExcelReportData(
            options: ReportOptions(years: [2026], includeCharts: false),
            entries: [],
            categoryNames: {},
            accountNames: {},
            investments: await repo.investments(),
            investmentEntries: await repo.investmentEntries(),
          ),
        ),
      );
      expect(wb.tables['รายการลงทุน']!.maxRows, 4);
      expect(
        wb.tables['รายการลงทุน']!.rows.first.any(
          (c) => c?.value.toString() == 'ID',
        ),
        false,
      );
      await expectLater(
        repo.addInvestmentEntry(
          InvestmentEntry(
            accountId: 1,
            fundId: fund.id!,
            amountMinor: 0,
            currentMinor: 0,
            date: DateTime(2026),
            createdAt: 1,
          ),
        ),
        throwsFormatException,
      );
      await expectLater(repo.deleteInvestment(fund.id!), throwsStateError);
      expect(await repo.investmentEntries(), hasLength(3));
    },
  );
  test(
    'deleting a fund also removes contributions recorded on an offline device',
    () async {
      final folder = await Directory.systemTemp.createTemp('fund-delete-sync');
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase(accountId: 'a'), b = AppDatabase(accountId: 'b');
      final dbA = await a.open(), dbB = await b.open();
      final repoA = FinanceRepository(dbA),
          repoB = FinanceRepository(dbB),
          remote = MemorySyncRemote();
      addTearDown(() async {
        await a.close();
        await b.close();
        await remote.dispose();
        await folder.delete(recursive: true);
      });
      Future<void> send(Database db) async {
        final local = SyncLocal(db);
        await local.apply(await remote.read('owner'));
        for (final change in await local.pending()) {
          final saved = await remote.write('owner', change);
          await local.acknowledge(change);
          await local.apply([saved]);
        }
      }

      await repoA.saveFund(
        Investment(
          name: 'Fund',
          investedMinor: 0,
          currentMinor: 0,
          currencyCode: 'THB',
          valuedAt: DateTime(2026),
        ),
      );
      await send(dbA);
      await send(dbB);
      final fundB = (await repoB.investments()).single;
      await dbB.insert(
        'investment_entries',
        InvestmentEntry(
          fundId: fundB.id!,
          amountMinor: 100,
          currentMinor: 100,
          date: DateTime(2026),
          createdAt: 1,
        ).toMap(),
      );
      await repoA.deleteInvestment((await repoA.investments()).single.id!);
      await send(dbA);
      await send(dbB);
      await send(dbA);
      expect(await repoB.investmentEntries(), isEmpty);
      expect(await repoB.investments(), isEmpty);
      expect(
        (await remote.read(
          'owner',
        )).where((r) => r.table == 'investment_entries').single.deleted,
        true,
      );
    },
  );
  test(
    'version nine adds account selection without debiting legacy deposits',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'fund-account-upgrade',
      );
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase();
      var db = await a.open();
      addTearDown(() async {
        await a.close();
        await folder.delete(recursive: true);
      });
      final repo = FinanceRepository(db);
      await repo.saveInvestment(
        Investment(
          name: 'Old fund',
          investedMinor: 0,
          currentMinor: 0,
          currencyCode: 'THB',
          valuedAt: DateTime(2026),
        ),
      );
      final fund = (await repo.investments()).single;
      await db.execute('DROP TABLE investment_entries');
      await db.execute(
        'CREATE TABLE investment_entries(id INTEGER PRIMARY KEY AUTOINCREMENT, fund_id INTEGER NOT NULL, amount_minor INTEGER NOT NULL, current_minor INTEGER NOT NULL, transaction_date TEXT NOT NULL, created_at INTEGER NOT NULL, note TEXT NOT NULL DEFAULT "", FOREIGN KEY(fund_id) REFERENCES investments(id) ON DELETE CASCADE)',
      );
      await initializeSyncSchema(db);
      await db.insert(
        'investment_entries',
        InvestmentEntry(
          fundId: fund.id!,
          amountMinor: 10000,
          currentMinor: 11000,
          date: DateTime(2026),
          createdAt: 1,
        ).toMap(),
      );
      await db.execute('PRAGMA user_version=9');
      // Reproduce a v9 connection retained by hot reload, before reopen/upgrade.
      await repo.addInvestmentEntry(
        InvestmentEntry(
          fundId: fund.id!,
          accountId: 1,
          amountMinor: 2500,
          currentMinor: 0,
          contributionOnly: true,
          date: DateTime(2026, 1, 2),
          createdAt: 2,
        ),
      );
      expect((await repo.entries()).single.amountMinor, 2500);
      await a.close();
      db = await a.open();
      final upgraded = FinanceRepository(db);
      expect(await db.getVersion(), 11);
      expect((await upgraded.investmentEntries()).last.accountId, isNull);
      expect((await upgraded.investments()).single.investedMinor, 12500);
      expect((await upgraded.investments()).single.currentMinor, 13500);
      expect((await upgraded.entries()).single.amountMinor, 2500);
    },
  );
  test('version eight migration keeps existing fund values', () async {
    final folder = await Directory.systemTemp.createTemp('fund-upgrade');
    await databaseFactory.setDatabasesPath(folder.path);
    final a = AppDatabase();
    var db = await a.open();
    addTearDown(() async {
      await a.close();
      await folder.delete(recursive: true);
    });
    await FinanceRepository(db).saveInvestment(
      Investment(
        name: 'Existing',
        investedMinor: 12300,
        currentMinor: 14000,
        currencyCode: 'USD',
        valuedAt: DateTime(2026),
      ),
    );
    await db.execute('DROP TABLE investment_entries');
    await db.execute('PRAGMA user_version=8');
    await a.close();
    db = await a.open();
    expect(await db.getVersion(), 11);
    expect(
      (await FinanceRepository(db).investments()).single.investedMinor,
      12300,
    );
    expect(await db.query('investment_entries'), isEmpty);
  });
}
