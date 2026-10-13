import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/investment.dart';
import '../models/investment_entry.dart';
import 'sync_record.dart';

class FirestoreSyncRemote implements SyncRemote {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  FirestoreSyncRemote(this.firestore, this.auth);
  CollectionReference<Map<String, dynamic>> _records(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('Account changed');
    return firestore.collection('users').doc(uid).collection('finance');
  }

  CollectionReference<Map<String, dynamic>> _investments(String uid) {
    if (auth.currentUser?.uid != uid) throw StateError('Account changed');
    return firestore.collection('users').doc(uid).collection('investments');
  }

  SyncRecord _decode(DocumentSnapshot<Map<String, dynamic>> doc) {
    final value = doc.data()!;
    if (value['schema'] != 1 ||
        !syncTables.contains(value['table']) ||
        value['deleted'] is! bool ||
        value['token'] is! String ||
        value['data'] is! Map) {
      throw const FormatException('Unsupported cloud data');
    }
    if (value['table'] == 'investments' && value['deleted'] != true)
      Investment.fromMap(
        Map<String, Object?>.from(value['data'] as Map),
      ).validate();
    if (value['table'] == 'investment_entries' && value['deleted'] != true) {
      final data = Map<String, Object?>.from(value['data'] as Map);
      if (data['fund_id'] is! String || (data['fund_id'] as String).isEmpty)
        throw const FormatException('Invalid fund reference');
      if (data['account_id'] != null &&
          (data['account_id'] is! String ||
              (data['account_id'] as String).isEmpty))
        throw const FormatException('Invalid funding account reference');
      InvestmentEntry.fromMap({
        ...data,
        'fund_id': 1,
        if (data['account_id'] != null) 'account_id': 1,
      }).validate();
    }
    return SyncRecord(
      id: doc.id,
      table: value['table'] as String,
      deleted: value['deleted'] as bool,
      token: value['token'] as String,
      data: Map<String, Object?>.from(value['data'] as Map),
    );
  }

  @override
  Stream<List<SyncRecord>> watch(String uid) {
    final sources = [_records(uid), _investments(uid)];
    return Stream<List<SyncRecord>>.multi((sink) {
      final values = <int, List<SyncRecord>>{};
      final subscriptions = <StreamSubscription>[];
      for (var i = 0; i < sources.length; i++) {
        final index = i;
        subscriptions.add(
          sources[i].snapshots(includeMetadataChanges: true).listen((snapshot) {
            if (snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites)
              return;
            try {
              values[index] = snapshot.docs.map(_decode).toList();
              if (values.length == 2) sink.add([...values[0]!, ...values[1]!]);
            } catch (e, stack) {
              sink.addError(e, stack);
            }
          }, onError: sink.addError),
        );
      }
      sink.onCancel = () async {
        for (final sub in subscriptions) await sub.cancel();
      };
    });
  }

  @override
  Future<List<SyncRecord>> read(String uid) async {
    final results = await Future.wait([
      _records(uid).get(const GetOptions(source: Source.server)),
      _investments(uid).get(const GetOptions(source: Source.server)),
    ]);
    return [for (final result in results) ...result.docs.map(_decode)];
  }

  @override
  Future<SyncRecord> write(String uid, SyncRecord record) async {
    final doc =
        (record.table == 'investments' || record.table == 'investment_entries'
                ? _investments(uid)
                : _records(uid))
            .doc(record.id);
    return firestore.runTransaction((txn) async {
      if (auth.currentUser?.uid != uid) throw StateError('Account changed');
      final previous = await txn.get(doc);
      if (previous.exists) {
        final old = _decode(previous);
        if (old.table != record.table)
          throw const FormatException('Entity type changed');
        // Tombstones are permanent; stale offline edits cannot resurrect deleted records.
        if (old.deleted || record.createOnly) return old;
      }
      txn.set(doc, {
        'schema': 1,
        'table': record.table,
        'data': record.data,
        'deleted': record.deleted,
        'token': record.token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return record;
    });
  }
}
