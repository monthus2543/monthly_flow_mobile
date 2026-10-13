import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_providers.dart';
import '../state/app_store.dart';
import 'firestore_sync_remote.dart';
import 'sync_local.dart';
import 'sync_record.dart';

enum SyncPhase { local, preparing, syncing, synced, pending, error }

class SyncState {
  final SyncPhase phase;
  final int pending;
  final DateTime? lastSync;
  const SyncState(this.phase, {this.pending = 0, this.lastSync});
}

final syncRemoteProvider = Provider<SyncRemote>(
  (ref) =>
      FirestoreSyncRemote(FirebaseFirestore.instance, FirebaseAuth.instance),
);
final syncCoordinatorProvider = NotifierProvider<SyncCoordinator, SyncState>(
  SyncCoordinator.new,
);

class SyncCoordinator extends Notifier<SyncState> {
  Timer? _debounce;
  Timer? _retry;
  StreamSubscription<List<SyncRecord>>? _subscription;
  String? _uid;
  int _epoch = 0;
  bool _running = false;
  bool _again = false;

  @override
  SyncState build() {
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.asData?.value?.id != next.asData?.value?.id ||
          next.isLoading ||
          next.hasError) {
        _epoch++;
        _uid = null;
        _subscription?.cancel();
        _subscription = null;
        _debounce?.cancel();
        state = const SyncState(SyncPhase.preparing);
      }
    });
    ref.listen(appStartupProvider, (previous, next) {
      if (next.isLoading) {
        _epoch++;
        _uid = null;
        _subscription?.cancel();
        _subscription = null;
        state = const SyncState(SyncPhase.preparing);
      } else if (next.hasValue) {
        _attach();
      }
    });
    ref.listen(financeChangesProvider, (previous, next) => request());
    _retry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_uid != null && _subscription == null) _attach();
      if (state.phase == SyncPhase.error || state.phase == SyncPhase.pending)
        request();
    });
    ref.onDispose(() {
      _epoch++;
      _debounce?.cancel();
      _retry?.cancel();
      _subscription?.cancel();
    });
    // The coordinator can be first watched after startup has already completed.
    Future.microtask(() {
      if (ref.mounted && ref.read(appStartupProvider).hasValue) _attach();
    });
    return const SyncState(SyncPhase.local);
  }

  void _attach() {
    final store = ref.read(appStoreProvider.notifier);
    final uid = store.activeAccountId;
    if (uid == null) {
      state = const SyncState(SyncPhase.local);
      return;
    }
    if (ref.read(authSessionProvider).asData?.value?.id != uid) return;
    if (_uid == uid && _subscription != null) return;
    _uid = uid;
    try {
      _subscription = ref
          .read(syncRemoteProvider)
          .watch(uid)
          .listen(
            (_) => request(),
            onError: (Object error) {
              if (ref.mounted && _uid == uid)
                state = const SyncState(SyncPhase.error);
            },
            onDone: () {
              if (ref.mounted && _uid == uid) {
                _subscription = null;
                state = const SyncState(SyncPhase.error);
              }
            },
          );
      request();
    } catch (_) {
      state = const SyncState(SyncPhase.error);
    }
    request();
  }

  void request() {
    if (!ref.mounted || _uid == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => synchronize());
  }

  Future<void> synchronize() async {
    if (_running) {
      _again = true;
      return;
    }
    final store = ref.read(appStoreProvider.notifier);
    final uid = _uid;
    if (uid == null ||
        store.activeAccountId != uid ||
        ref.read(appStartupProvider).isLoading)
      return;
    final epoch = _epoch;
    bool current() =>
        ref.mounted &&
        epoch == _epoch &&
        _uid == uid &&
        store.activeAccountId == uid &&
        ref.read(authSessionProvider).asData?.value?.id == uid;
    _running = true;
    _again = false;
    final lastSync = state.lastSync;
    try {
      state = SyncState(
        SyncPhase.syncing,
        pending: state.pending,
        lastSync: lastSync,
      );
      final local = SyncLocal(await store.database.open());
      if (!current()) return;
      state = SyncState(
        SyncPhase.syncing,
        pending: await local.pendingCount(),
        lastSync: lastSync,
      );
      final remote = ref.read(syncRemoteProvider);
      final cloud = await remote.read(uid).timeout(const Duration(seconds: 12));
      if (!current()) return;
      await local.apply(cloud);
      final pending = await local.pending();
      for (final record in pending) {
        if (!current()) return;
        final saved = await remote
            .write(uid, record)
            .timeout(const Duration(seconds: 12));
        if (!current()) return;
        if (await local.acknowledge(record)) await local.apply([saved]);
      }
      if (!current()) return;
      await store.refresh(notifySync: false);
      if (!current()) return;
      await store.catchUpRecurring();
      final remaining = await local.pendingCount();
      if (!current()) return;
      state = SyncState(
        remaining == 0 ? SyncPhase.synced : SyncPhase.pending,
        pending: remaining,
        lastSync: DateTime.now(),
      );
    } catch (_) {
      if (current())
        state = SyncState(
          SyncPhase.error,
          pending: state.pending,
          lastSync: lastSync,
        );
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        request();
      }
    }
  }
}
