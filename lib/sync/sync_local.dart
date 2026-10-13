import 'package:sqflite/sqflite.dart';
import 'sync_record.dart';

/// SQLite triggers journal every finance mutation in the same transaction.
/// Device preferences, PINs, tokens and local receipt paths never enter this journal.
Future<void> initializeSyncSchema(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS sync_control (id INTEGER PRIMARY KEY, applying INTEGER NOT NULL DEFAULT 0)',
  );
  await db.execute(
    'INSERT OR IGNORE INTO sync_control(id, applying) VALUES(1, 0)',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS sync_records (
    entity_id TEXT PRIMARY KEY, table_name TEXT NOT NULL, local_id INTEGER NOT NULL,
    dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0,
    generation INTEGER NOT NULL DEFAULT 1, cloud_token TEXT NOT NULL DEFAULT '',
    create_only INTEGER NOT NULL DEFAULT 0, UNIQUE(table_name, local_id))''');
  await db.execute(
    'CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );
  const defaults = [
    'salary',
    'other_income',
    'food',
    'travel',
    'housing',
    'shopping',
    'entertainment',
    'other',
  ];
  for (final table in syncTables) {
    for (final row in await db.query(table)) {
      final id = row['id'] as int;
      final seed =
          table == 'accounts' && id == 1 || table == 'categories' && id <= 8;
      final pristine = table == 'accounts'
          ? row['name'] == 'cash' && row['opening_balance_minor'] == 0
          : table == 'categories' && id <= 8
          ? row['name'] == defaults[id - 1] &&
                row['is_active'] == 1 &&
                row['color_value'] == null
          : false;
      await db.insert('sync_records', {
        'entity_id': seed ? 'seed_${table}_$id' : newSyncId(),
        'table_name': table,
        'local_id': id,
        'create_only': pristine ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final event in ['INSERT', 'UPDATE']) {
      // Budget identity is shared for the same month/category on two devices.
      final identity = table == 'budgets'
          ? "'budget_' || NEW.month || '_' || COALESCE((SELECT entity_id FROM sync_records WHERE table_name = 'categories' AND local_id = NEW.category_id), 'overall')"
          : 'lower(hex(randomblob(16)))';
      final body = event == 'INSERT'
          ? "INSERT INTO sync_records(entity_id,table_name,local_id,dirty,deleted,generation) VALUES($identity,'$table',NEW.id,1,0,1) ON CONFLICT(entity_id) DO UPDATE SET local_id=NEW.id,dirty=1,deleted=0,generation=generation+1,create_only=0;"
          : "UPDATE sync_records SET dirty=1,deleted=0,generation=generation+1,create_only=0 WHERE table_name='$table' AND local_id=NEW.id;";
      await db.execute(
        "CREATE TRIGGER IF NOT EXISTS sync_${table}_${event.toLowerCase()} AFTER $event ON $table WHEN (SELECT applying FROM sync_control WHERE id=1)=0 BEGIN $body END",
      );
    }
    await db.execute(
      "CREATE TRIGGER IF NOT EXISTS sync_${table}_delete AFTER DELETE ON $table WHEN (SELECT applying FROM sync_control WHERE id=1)=0 BEGIN UPDATE sync_records SET dirty=1,deleted=1,generation=generation+1,create_only=0,local_id=-(SELECT COALESCE(MAX(ABS(local_id)),0)+1 FROM sync_records) WHERE table_name='$table' AND local_id=OLD.id; END",
    );
  }
}

class SyncLocal {
  final Database db;
  const SyncLocal(this.db);
  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sync_records WHERE dirty=1'),
      ) ??
      0;

  Future<List<SyncRecord>> pending() async {
    return db.transaction((txn) async {
      final records = await txn.query('sync_records', where: 'dirty=1');
      final result = <SyncRecord>[];
      for (final record in records) {
        final table = record['table_name'] as String;
        final deleted = record['deleted'] == 1;
        final rows = deleted
            ? <Map<String, Object?>>[]
            : await txn.query(
                table,
                where: 'id=?',
                whereArgs: [record['local_id']],
              );
        final data = rows.isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(rows.single);
        data.remove('id');
        if (!(data['receipt_path'] is String &&
            ((data['receipt_path'] as String).isEmpty ||
                (data['receipt_path'] as String).startsWith(
                  'firebase-storage://',
                )))) {
          data.remove('receipt_path');
        }
        for (final reference in {
          'category_id': 'categories',
          'account_id': 'accounts',
          'fund_id': 'investments',
        }.entries) {
          if (data[reference.key] != null) {
            final mapping = await txn.query(
              'sync_records',
              where: 'table_name=? AND local_id=?',
              whereArgs: [reference.value, data[reference.key]],
            );
            if (mapping.isEmpty) throw StateError('Missing finance reference');
            data[reference.key] = mapping.single['entity_id'];
          }
        }
        result.add(
          SyncRecord(
            id: record['entity_id'] as String,
            table: table,
            data: data,
            deleted: deleted,
            token: newSyncId(),
            generation: record['generation'] as int,
            createOnly: record['create_only'] == 1,
          ),
        );
      }
      result.sort(
        (a, b) =>
            syncTables.indexOf(a.table).compareTo(syncTables.indexOf(b.table)),
      );
      return result;
    });
  }

  Future<bool> acknowledge(SyncRecord record) async {
    // A write made while uploading must remain pending.
    return await db.update(
          'sync_records',
          {'dirty': 0, 'create_only': 0},
          where: 'entity_id=? AND generation=?',
          whereArgs: [record.id, record.generation],
        ) ==
        1;
  }

  Future<void> apply(List<SyncRecord> input) async {
    final records = [...input]
      ..sort(
        (a, b) =>
            syncTables.indexOf(a.table).compareTo(syncTables.indexOf(b.table)),
      );
    await db.transaction((txn) async {
      await txn.update('sync_control', {'applying': 1}, where: 'id=1');
      for (final remote in records) {
        if (!syncTables.contains(remote.table))
          throw const FormatException('Unknown cloud entity');
        if (remote.table == 'investment_entries' && !remote.deleted) {
          final parent = await txn.query(
            'sync_records',
            where: 'entity_id=? AND table_name=?',
            whereArgs: [remote.data['fund_id'], 'investments'],
          );
          if (parent.isNotEmpty && parent.single['deleted'] == 1) {
            // A contribution arriving after its fund was deleted must stay deleted.
            final old = await txn.query(
              'sync_records',
              where: 'entity_id=?',
              whereArgs: [remote.id],
            );
            if (old.isEmpty) {
              final reserved = -(Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COALESCE(MAX(ABS(local_id)),0)+1 FROM sync_records',
                ),
              )!);
              await txn.insert('sync_records', {
                'entity_id': remote.id,
                'table_name': remote.table,
                'local_id': reserved,
                'deleted': 1,
                'dirty': 1,
              });
            } else {
              await txn.rawUpdate(
                'UPDATE sync_records SET dirty=1, deleted=1, generation=generation+1 WHERE entity_id=? AND deleted=0',
                [remote.id],
              );
            }
            continue;
          }
        }
        final matches = await txn.query(
          'sync_records',
          where: 'entity_id=?',
          whereArgs: [remote.id],
        );
        final mapping = matches.firstOrNull;
        if (mapping != null && mapping['table_name'] != remote.table)
          throw const FormatException('Entity type changed');
        if (mapping?['dirty'] == 1 || mapping?['cloud_token'] == remote.token)
          continue;
        var localId = mapping?['local_id'] as int?;
        if (remote.deleted) {
          if (localId != null) {
            if (remote.table == 'investments') {
              await txn.rawUpdate(
                "UPDATE sync_records SET deleted=1,dirty=1,generation=generation+1 WHERE table_name='investment_entries' AND local_id IN (SELECT id FROM investment_entries WHERE fund_id=?)",
                [localId],
              );
            }
            if (remote.table == 'categories' || remote.table == 'accounts') {
              await txn.update(
                remote.table,
                {'is_active': 0},
                where: 'id=?',
                whereArgs: [localId],
              );
            } else {
              await txn.delete(
                remote.table,
                where: 'id=?',
                whereArgs: [localId],
              );
            }
          }
          // Reserve a mapping even if this device never saw the live row.
          localId ??=
              -(Sqflite.firstIntValue(
                    await txn.rawQuery('SELECT COUNT(*) FROM sync_records'),
                  )! +
                  1);
        } else {
          final data = Map<String, Object?>.from(remote.data)..remove('id');
          if (!(data['receipt_path'] is String &&
              ((data['receipt_path'] as String).isEmpty ||
                  (data['receipt_path'] as String).startsWith(
                    'firebase-storage://',
                  )))) {
            data.remove('receipt_path');
          }
          for (final reference in {
            'category_id': 'categories',
            'account_id': 'accounts',
            'fund_id': 'investments',
          }.entries) {
            if (data[reference.key] != null) {
              final target = await txn.query(
                'sync_records',
                where: 'entity_id=? AND table_name=?',
                whereArgs: [data[reference.key], reference.value],
              );
              if (target.isEmpty || (target.single['local_id'] as int) < 0)
                throw StateError('Cloud reference not available');
              data[reference.key] = target.single['local_id'];
            }
          }
          if (localId == null || localId < 0) {
            localId = await txn.insert(remote.table, data);
          } else {
            final updated = await txn.update(
              remote.table,
              data,
              where: 'id=?',
              whereArgs: [localId],
            );
            if (updated == 0)
              await txn.insert(remote.table, {...data, 'id': localId});
          }
        }
        await txn.insert('sync_records', {
          'entity_id': remote.id,
          'table_name': remote.table,
          'local_id': localId,
          'dirty': 0,
          'deleted': remote.deleted ? 1 : 0,
          'generation': mapping?['generation'] ?? 1,
          'cloud_token': remote.token,
          'create_only': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.update('sync_control', {'applying': 0}, where: 'id=1');
    });
  }

  /// Import once into the first Google account. The guest original remains intact.
  /// Stable entity IDs make retries after a crash idempotent.
  static Future<void> importGuest(
    Database guest,
    Database account,
    String uid,
  ) async {
    final complete = await account.query(
      'sync_meta',
      where: "key='guest_import_done'",
    );
    if (complete.isNotEmpty) return;
    final permitted = await guest.transaction((txn) async {
      final owner = await txn.query('sync_meta', where: "key='guest_owner'");
      if (owner.isNotEmpty && owner.single['value'] != uid) return false;
      await txn.insert('sync_meta', {
        'key': 'guest_owner',
        'value': uid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
    if (!permitted) {
      await account.insert('sync_meta', {
        'key': 'guest_import_done',
        'value': '1',
      });
      return;
    }
    // Claim before copying so a crash cannot import the same guest data into another account.
    final rows = await SyncLocal(guest).pendingAll();
    await account.transaction((txn) async {
      await txn.update('sync_control', {'applying': 1}, where: 'id=1');
      // New profile contains only deterministic defaults; replace them with the guest copy.
      for (final table in syncTables.reversed) {
        await txn.delete(table);
      }
      await txn.delete('sync_records');
      for (final table in syncTables) {
        for (final row in rows[table]!) {
          await txn.insert(table, row);
        }
      }
      for (final row in rows['sync_records']!) {
        await txn.insert('sync_records', {
          ...row,
          'dirty': 1,
          'cloud_token': '',
        });
      }
      await txn.insert('sync_meta', {'key': 'guest_import_done', 'value': '1'});
      await txn.update('sync_control', {'applying': 0}, where: 'id=1');
    });
  }

  Future<Map<String, List<Map<String, Object?>>>> pendingAll() async =>
      db.transaction(
        (txn) async => {
          for (final table in [...syncTables, 'sync_records'])
            table: await txn.query(table),
        },
      );
}
