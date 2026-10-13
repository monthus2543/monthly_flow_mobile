import 'dart:math';

const syncTables = [
  'categories',
  'accounts',
  'transactions',
  'budgets',
  'recurring_rules',
  'saving_goals',
  'bill_reminders',
  'investments',
  'investment_entries',
];
String newSyncId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class SyncRecord {
  final String id;
  final String table;
  final Map<String, Object?> data;
  final bool deleted;
  final String token;
  final int generation;
  final bool createOnly;
  const SyncRecord({
    required this.id,
    required this.table,
    required this.data,
    required this.deleted,
    required this.token,
    this.generation = 0,
    this.createOnly = false,
  });
}

abstract interface class SyncRemote {
  Stream<List<SyncRecord>> watch(String uid);
  Future<List<SyncRecord>> read(String uid);
  Future<SyncRecord> write(String uid, SyncRecord record);
}
