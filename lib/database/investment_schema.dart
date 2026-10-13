import 'package:sqflite/sqflite.dart';

/// Also handles an already-open database retained by a Flutter hot reload.
/// Checking columns makes the subsequent normal version upgrade idempotent.
Future<void> ensureInvestmentEntryColumns(DatabaseExecutor db) async {
  final columns = (await db.rawQuery(
    'PRAGMA table_info(investment_entries)',
  )).map((row) => row['name']).toSet();
  if (columns.isEmpty)
    throw StateError('Investment entries table not available');
  if (!columns.contains('account_id')) {
    await db.execute(
      'ALTER TABLE investment_entries ADD COLUMN account_id INTEGER REFERENCES accounts(id)',
    );
  }
  if (!columns.contains('contribution_only')) {
    await db.execute(
      'ALTER TABLE investment_entries ADD COLUMN contribution_only INTEGER NOT NULL DEFAULT 0',
    );
  }
}
