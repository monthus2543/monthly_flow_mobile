import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monthly_flow/database/app_database.dart';
import 'package:monthly_flow/models/investment.dart';
import 'package:monthly_flow/repositories/finance_repository.dart';
import 'package:monthly_flow/screens/investments_screen.dart';
import 'package:monthly_flow/sync/sync_local.dart';
import 'package:monthly_flow/export/excel_report.dart';
import 'package:excel_plus/excel_plus.dart';
import 'support/memory_sync_remote.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test(
    'manual amounts keep minor units exact and zero cost has no return percentage',
    () {
      expect(parseInvestmentAmount('1,234.56'), 123456);
      expect(parseInvestmentAmount('0'), 0);
      expect(parseInvestmentAmount('-10'), isNull);
      expect(parseInvestmentAmount('1.234'), isNull);
      final v = Investment(
        name: 'Fund',
        investedMinor: 10000,
        currentMinor: 12500,
        currencyCode: 'USD',
        valuedAt: DateTime(2026, 10, 13),
      );
      expect(v.gainMinor, 2500);
      expect(v.returnPercent, 25);
      expect(
        Investment(
          name: 'Gift',
          investedMinor: 0,
          currentMinor: 100,
          currencyCode: 'THB',
          valuedAt: DateTime(2026),
        ).returnPercent,
        isNull,
      );
    },
  );
  test(
    'portfolios persist, sync edits/deletions, and leave cash transactions untouched',
    () async {
      final folder = await Directory.systemTemp.createTemp('portfolio-test');
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase(accountId: 'a'), b = AppDatabase(accountId: 'b');
      final dbA = await a.open(), dbB = await b.open();
      addTearDown(() async {
        await a.close();
        await b.close();
        await folder.delete(recursive: true);
      });
      final repo = FinanceRepository(dbA), remote = MemorySyncRemote();
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

      await repo.saveInvestment(
        Investment(
          name: 'Portfolio',
          investedMinor: 100000,
          currentMinor: 110000,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 10, 13),
        ),
      );
      expect(await repo.entries(), isEmpty);
      await send(dbA);
      await send(dbB);
      expect(
        (await FinanceRepository(dbB).investments()).single.gainMinor,
        10000,
      );
      final item = (await repo.investments()).single;
      await repo.saveInvestment(
        Investment(
          id: item.id,
          name: item.name,
          investedMinor: 100000,
          currentMinor: 90000,
          currencyCode: 'THB',
          valuedAt: DateTime(2026, 10, 13),
        ),
      );
      await send(dbA);
      await send(dbB);
      expect(
        (await FinanceRepository(dbB).investments()).single.gainMinor,
        -10000,
      );
      await repo.deleteInvestment(item.id!);
      await send(dbA);
      await send(dbB);
      expect(await FinanceRepository(dbB).investments(), isEmpty);
      expect(
        (await remote.read(
          'another-owner',
        )).where((v) => v.table == 'investments'),
        isEmpty,
      );
    },
  );
  test(
    'version seven database upgrades without losing existing finance data',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'portfolio-migration',
      );
      await databaseFactory.setDatabasesPath(folder.path);
      final a = AppDatabase();
      var db = await a.open();
      final categories = await db.query('categories');
      await db.execute('DROP TABLE investment_entries');
      await db.execute('DROP TABLE investments');
      await db.execute('PRAGMA user_version=7');
      await a.close();
      db = await a.open();
      expect(await db.query('categories'), categories);
      expect(await db.query('investments'), isEmpty);
      await a.close();
      await folder.delete(recursive: true);
    },
  );
  test(
    'Excel exports manual snapshots with currency and cell-linked gain formulas',
    () {
      final v = Investment(
        name: 'Fund',
        investedMinor: 100000,
        currentMinor: 120000,
        currencyCode: 'USD',
        valuedAt: DateTime(2026, 10, 13),
      );
      final wb = Excel.decodeBytes(
        buildExcelReport(
          ExcelReportData(
            options: ReportOptions(years: [2026], includeCharts: false),
            entries: [],
            categoryNames: {},
            accountNames: {},
            investments: [v],
          ),
        ),
      );
      final s = wb['พอร์ตกรอกเอง'];
      expect(s.cell(CellIndex.indexByString('B2')).value, TextCellValue('USD'));
      expect(s.evaluate(CellIndex.indexByString('E2')).toString(), '200');
      expect(s.evaluate(CellIndex.indexByString('F2')).toString(), '0.2');
      Directory('build/export-preview').createSync(recursive: true);
      File('build/export-preview/investment-report.xlsx').writeAsBytesSync(
        buildExcelReport(
          ExcelReportData(
            options: ReportOptions(years: [2026], includeCharts: false),
            entries: [],
            categoryNames: {},
            accountNames: {},
            investments: [v],
          ),
        ),
      );
    },
  );
}
