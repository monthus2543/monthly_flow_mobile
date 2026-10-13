import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/database/app_database.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/repositories/finance_repository.dart';
import 'package:monthly_flow/sync/sync_local.dart';
import 'package:monthly_flow/sync/sync_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/memory_sync_remote.dart';

Future<void> exchange(
  Database db,
  MemorySyncRemote cloud, {
  String uid = 'user',
}) async {
  final local = SyncLocal(db);
  await local.apply(await cloud.read(uid));
  for (final change in await local.pending()) {
    final saved = await cloud.write(uid, change);
    if (await local.acknowledge(change)) await local.apply([saved]);
  }
}

Entry entry(String title, {int category = 3, String receipt = ''}) => Entry(
  title: title,
  amountMinor: 10000,
  type: expense,
  categoryId: category,
  date: DateTime(2026, 10, 6),
  createdAt: 1,
  receiptPath: receipt,
);

void main() {
  late Directory directory;
  late AppDatabase a;
  late AppDatabase b;
  late Database dbA;
  late Database dbB;
  late MemorySyncRemote cloud;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('monthly-sync-test-');
    await databaseFactory.setDatabasesPath(directory.path);
    a = AppDatabase(accountId: 'device-a');
    b = AppDatabase(accountId: 'device-b');
    dbA = await a.open();
    dbB = await b.open();
    cloud = MemorySyncRemote();
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await cloud.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'offline pending changes survive database restart and remote failure',
    () async {
      await FinanceRepository(dbA).save(entry('Offline expense'));
      cloud.offline = true;
      await expectLater(exchange(dbA, cloud), throwsStateError);
      await a.close();
      dbA = await a.open();
      expect(
        (await FinanceRepository(dbA).entries()).single.title,
        'Offline expense',
      );
      expect(await SyncLocal(dbA).pendingCount(), greaterThan(0));
      cloud.offline = false;
      await exchange(dbA, cloud);
      expect(await SyncLocal(dbA).pendingCount(), 0);
    },
  );
  test(
    'two devices with colliding numeric IDs merge and retain foreign references',
    () async {
      await FinanceRepository(
        dbA,
      ).saveCategory(const Category(0, 'Custom A', expense, 'food'));
      await FinanceRepository(
        dbB,
      ).saveCategory(const Category(0, 'Custom B', expense, 'food'));
      await FinanceRepository(dbA).save(entry('A', category: 9));
      await FinanceRepository(dbB).save(entry('B', category: 9));
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      await exchange(dbA, cloud);
      final repo = FinanceRepository(dbA);
      final entries = await repo.entries();
      final cats = await repo.categories();
      expect(entries.length, 2);
      for (final value in entries) {
        expect(
          cats.singleWhere((c) => c.id == value.categoryId).name,
          'Custom ${value.title}',
        );
      }
      expect(await SyncLocal(dbA).pendingCount(), 0);
    },
  );
  test('cloud receipt references and removal sync across devices', () async {
    const receipt =
        'firebase-storage://users/user/receipts/0123456789abcdef0123456789abcdef.jpg';
    final repo = FinanceRepository(dbA);
    await repo.save(entry('Cloud receipt', receipt: receipt));
    await exchange(dbA, cloud);
    await exchange(dbB, cloud);
    expect(
      (await FinanceRepository(dbB).entries()).single.receiptPath,
      receipt,
    );
    final saved = (await repo.entries()).single;
    await repo.save(
      Entry.fromMap({...saved.toMap(), 'id': saved.id, 'receipt_path': ''}),
    );
    await exchange(dbA, cloud);
    await exchange(dbB, cloud);
    expect(
      (await FinanceRepository(dbB).entries()).single.receiptPath,
      isEmpty,
    );
  });
  test('category colors persist and sync across devices, including edits', () async {
    final repo = FinanceRepository(dbA);
    await repo.saveCategory(const Category(0, 'Custom color', expense, 'other', colorValue: 0xff2563eb));
    await exchange(dbA, cloud);
    await exchange(dbB, cloud);
    final saved = (await repo.categories()).singleWhere((c) => c.name == 'Custom color');
    expect((await FinanceRepository(dbB).categories()).singleWhere((c) => c.name == saved.name).colorValue, 0xff2563eb);
    await repo.saveCategory(Category(saved.id, saved.name, saved.type, saved.icon, colorValue: 0xff7c3aed));
    await a.close();
    dbA = await a.open();
    expect((await FinanceRepository(dbA).categories()).singleWhere((c) => c.name == saved.name).colorValue, 0xff7c3aed);
    await exchange(dbA, cloud);
    await exchange(dbB, cloud);
    expect((await FinanceRepository(dbB).categories()).singleWhere((c) => c.name == saved.name).colorValue, 0xff7c3aed);
  });
  test('version 6 database upgrades without losing categories or entries', () async {
    await FinanceRepository(dbA).save(entry('Preserved entry'));
    await dbA.execute('ALTER TABLE categories DROP COLUMN color_value');
    await dbA.setVersion(6);
    await a.close();
    dbA = await a.open();
    expect(await dbA.getVersion(), 11);
    expect((await FinanceRepository(dbA).entries()).single.title, 'Preserved entry');
    expect((await FinanceRepository(dbA).categories()).every((c) => c.colorValue == null), isTrue);
    await FinanceRepository(dbA).saveCategory(const Category(0, 'New color', income, 'other', colorValue: 0xff123456));
    expect((await FinanceRepository(dbA).categories()).singleWhere((c) => c.name == 'New color').colorValue, 0xff123456);
  });
  test(
    'local receipt paths and device settings never appear in cloud',
    () async {
      await FinanceRepository(dbA).setting('pin_hash', 'secret-pin');
      await FinanceRepository(
        dbA,
      ).save(entry('Receipt', receipt: '/private/device/receipt.jpg'));
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      expect(
        (await FinanceRepository(dbA).entries()).single.receiptPath,
        '/private/device/receipt.jpg',
      );
      expect(
        (await FinanceRepository(dbB).entries()).single.receiptPath,
        isEmpty,
      );
      expect(
        cloud.accounts['user']!.values.any(
          (r) => r.data.containsKey('receipt_path'),
        ),
        isFalse,
      );
      expect(
        cloud.accounts['user']!.values.any((r) => r.table == 'settings'),
        isFalse,
      );
      expect(await FinanceRepository(dbB).settings(), isEmpty);
    },
  );
  test(
    'tombstones propagate and stale offline edits cannot resurrect a deletion',
    () async {
      await FinanceRepository(dbA).save(entry('Delete me'));
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      final old = (await FinanceRepository(dbB).entries()).single;
      await FinanceRepository(dbB).save(
        Entry(
          id: old.id,
          title: 'Stale edit',
          amountMinor: old.amountMinor,
          type: old.type,
          categoryId: old.categoryId,
          date: old.date,
          createdAt: old.createdAt,
        ),
      );
      await FinanceRepository(
        dbA,
      ).delete((await FinanceRepository(dbA).entries()).single.id!);
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      expect(await FinanceRepository(dbB).entries(), isEmpty);
      expect(
        cloud.accounts['user']!.values
            .where((r) => r.table == 'transactions')
            .single
            .deleted,
        isTrue,
      );
    },
  );
  test('upload acknowledgment cannot clear a newer local edit', () async {
    await FinanceRepository(dbA).save(entry('Before'));
    final pending = (await SyncLocal(
      dbA,
    ).pending()).singleWhere((r) => r.table == 'transactions');
    await dbA.update('transactions', {'title': 'After'});
    expect(await SyncLocal(dbA).acknowledge(pending), isFalse);
    expect(
      (await SyncLocal(
        dbA,
      ).pending()).singleWhere((r) => r.table == 'transactions').data['title'],
      'After',
    );
  });
  test(
    'guest import is automatic, idempotent and limited to the first account',
    () async {
      await FinanceRepository(dbA).save(entry('Guest'));
      await SyncLocal.importGuest(dbA, dbB, 'first-user');
      await SyncLocal.importGuest(dbA, dbB, 'first-user');
      expect((await FinanceRepository(dbB).entries()).length, 1);
      expect((await FinanceRepository(dbA).entries()).length, 1);
      final other = AppDatabase(accountId: 'different-user');
      final otherDb = await other.open();
      await SyncLocal.importGuest(dbA, otherDb, 'different-user');
      expect(await FinanceRepository(otherDb).entries(), isEmpty);
      await other.close();
    },
  );
  test(
    'new device defaults do not overwrite customized categories in cloud',
    () async {
      await FinanceRepository(
        dbA,
      ).saveCategory(const Category(3, 'My Food', expense, 'food'));
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      expect(
        (await FinanceRepository(
          dbB,
        ).categories()).singleWhere((c) => c.id == 3).name,
        'My Food',
      );
    },
  );
  test(
    'monthly budgets created offline on two devices share one cloud identity',
    () async {
      await FinanceRepository(
        dbA,
      ).saveBudget(const Budget(month: '2026-10', amountMinor: 10000));
      await FinanceRepository(
        dbB,
      ).saveBudget(const Budget(month: '2026-10', amountMinor: 20000));
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      await exchange(dbA, cloud);
      expect(
        (await FinanceRepository(dbA).budgets()).single.amountMinor,
        20000,
      );
      expect(
        cloud.accounts['user']!.values
            .where((r) => r.table == 'budgets')
            .length,
        1,
      );
    },
  );
  test(
    'same recurring occurrence generated on two devices is not duplicated',
    () async {
      await FinanceRepository(dbA).saveRecurringRule(
        const RecurringRule(
          title: 'Monthly',
          amountMinor: 10000,
          type: expense,
          categoryId: 3,
          dayOfMonth: 6,
        ),
      );
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      final ruleA = (await FinanceRepository(dbA).recurringRules()).single;
      final ruleB = (await FinanceRepository(dbB).recurringRules()).single;
      await FinanceRepository(
        dbA,
      ).recordRecurringOccurrence(ruleA, entry('Monthly'), '2026-10');
      await FinanceRepository(
        dbB,
      ).recordRecurringOccurrence(ruleB, entry('Monthly'), '2026-10');
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      await exchange(dbA, cloud);
      expect((await FinanceRepository(dbA).entries()).length, 1);
      expect(
        cloud.accounts['user']!.values
            .where((r) => r.table == 'transactions')
            .length,
        1,
      );
    },
  );
  test(
    'backup replacement journals removals and new rows without reusing tombstones',
    () async {
      await FinanceRepository(dbA).save(entry('Old'));
      await exchange(dbA, cloud);
      final backup = <String, List<Map<String, Object?>>>{};
      for (final table in [...syncTables, 'settings']) {
        backup[table] = await dbA.query(table);
      }
      backup['transactions'] = [
        {...backup['transactions']!.single, 'title': 'Restored'},
      ];
      await FinanceRepository(dbA).replaceBackup(backup);
      await exchange(dbA, cloud);
      await exchange(dbB, cloud);
      expect((await FinanceRepository(dbB).entries()).single.title, 'Restored');
    },
  );
  test(
    'repeating local recurring generation is idempotent after a deletion',
    () async {
      final repo = FinanceRepository(dbA);
      await repo.saveRecurringRule(
        const RecurringRule(
          title: 'Monthly',
          amountMinor: 10000,
          type: expense,
          categoryId: 3,
          dayOfMonth: 6,
        ),
      );
      final rule = (await repo.recurringRules()).single;
      await repo.recordRecurringOccurrence(rule, entry('Monthly'), '2026-10');
      await repo.recordRecurringOccurrence(rule, entry('Monthly'), '2026-10');
      expect((await repo.entries()).length, 1);
      await repo.delete((await repo.entries()).single.id!);
      await repo.recordRecurringOccurrence(rule, entry('Monthly'), '2026-10');
      expect(await repo.entries(), isEmpty);
    },
  );
  test('invalid cloud reference rolls back atomically', () async {
    final bad = SyncRecord(
      id: 'bad',
      table: 'transactions',
      data: {...entry('Bad').toMap(), 'category_id': 'missing'},
      deleted: false,
      token: 'bad',
    );
    await expectLater(SyncLocal(dbA).apply([bad]), throwsStateError);
    expect(await FinanceRepository(dbA).entries(), isEmpty);
    expect((await dbA.query('sync_control')).single['applying'], 0);
  });
}
