import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery, Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/core/database/fluxer_database.dart';
import 'package:fluxer_app/core/gateway/presence_update_batcher.dart';

import '../../helpers/open_test_database.dart';

void main() {
  test('PresenceUpdateBatcher applies current user immediately', () async {
    final FluxerDatabase database = openTestDatabase();
    final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
      database: database,
      currentUserId: 'self',
      batchDelay: const Duration(milliseconds: 100),
    );
    addTearDown(batcher.dispose);
    await database.userDao.upsertUser(
      UsersCompanion.insert(id: 'self', username: 'self'),
    );
    batcher.enqueue(userId: 'self', status: 'idle');
    await Future<void>.delayed(Duration.zero);
    final User? user = await database.userDao.getUserById('self');
    expect(user?.status, 'idle');
  });

  test('PresenceUpdateBatcher coalesces other users into one batch', () async {
    final FluxerDatabase database = openTestDatabase();
    final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
      database: database,
      currentUserId: 'self',
      batchDelay: const Duration(milliseconds: 50),
    );
    addTearDown(batcher.dispose);
    await database.userDao.upsertUsers([
      UsersCompanion.insert(id: 'u1', username: 'u1'),
      UsersCompanion.insert(id: 'u2', username: 'u2'),
    ]);
    batcher
      ..enqueue(userId: 'u1', status: 'online')
      ..enqueue(userId: 'u2', status: 'dnd')
      ..enqueue(userId: 'u1', status: 'idle');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final User? u1 = await database.userDao.getUserById('u1');
    final User? u2 = await database.userDao.getUserById('u2');
    expect(u1?.status, 'idle');
    expect(u2?.status, 'dnd');
  });

  test('PresenceUpdateBatcher persists mobile flag for other users', () async {
    final FluxerDatabase database = openTestDatabase();
    final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
      database: database,
      currentUserId: 'self',
      batchDelay: const Duration(milliseconds: 50),
    );
    addTearDown(batcher.dispose);
    await database.userDao.upsertUser(
      UsersCompanion.insert(id: 'u1', username: 'u1'),
    );
    batcher.enqueue(userId: 'u1', status: 'online', mobile: true);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final User? user = await database.userDao.getUserById('u1');
    expect(user?.mobile, isTrue);
  });

  test('PresenceUpdateBatcher stores a user that had no row', () async {
    final FluxerDatabase database = openTestDatabase();
    final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
      database: database,
      currentUserId: 'self',
      batchDelay: const Duration(milliseconds: 50),
    );
    addTearDown(batcher.dispose);
    batcher.enqueue(
      userId: 'u1',
      status: 'dnd',
      user: UsersCompanion.insert(id: 'u1', username: 'friend'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final User? user = await database.userDao.getUserById('u1');
    expect(user?.username, 'friend');
    expect(user?.status, 'dnd');
  });

  group('writes that change nothing', () {
    const Duration pastFlush = Duration(milliseconds: 600);

    Future<FluxerDatabase> seededDatabase(List<UsersCompanion> users) async {
      final FluxerDatabase database = openTestDatabase();
      await database.userDao.upsertUsers(users);
      await pumpEventQueue();
      return database;
    }

    T settle<T>(FakeAsync async, Future<T> future) {
      late T value;
      unawaited(future.then((T v) => value = v));
      async.flushMicrotasks();
      return value;
    }

    test(
      'resending the stored presence leaves users watchers silent (no twice-a-second re-query storm)',
      () async {
        final FluxerDatabase database = await seededDatabase([
          UsersCompanion.insert(
            id: 'u1',
            username: 'u1',
          ).copyWith(status: const Value('online')),
        ]);

        fakeAsync((FakeAsync async) {
          final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
            database: database,
            currentUserId: 'self',
          );
          final List<Set<TableUpdate>> emissions = <Set<TableUpdate>>[];
          final StreamSubscription<Set<TableUpdate>> sub = database
              .tableUpdates(TableUpdateQuery.onTable(database.users))
              .listen(emissions.add);

          batcher.enqueue(userId: 'u1', status: 'online');
          async
            ..elapse(pastFlush)
            ..flushMicrotasks();

          expect(emissions, isEmpty);
          unawaited(sub.cancel());
          batcher.dispose();
        });
      },
    );

    test('a changed status still writes and notifies exactly once', () async {
      final FluxerDatabase database = await seededDatabase([
        UsersCompanion.insert(
          id: 'u1',
          username: 'u1',
        ).copyWith(status: const Value('online')),
      ]);

      fakeAsync((FakeAsync async) {
        final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
          database: database,
          currentUserId: 'self',
        );
        final List<Set<TableUpdate>> emissions = <Set<TableUpdate>>[];
        final StreamSubscription<Set<TableUpdate>> sub = database
            .tableUpdates(TableUpdateQuery.onTable(database.users))
            .listen(emissions.add);

        batcher.enqueue(userId: 'u1', status: 'idle');
        async
          ..elapse(pastFlush)
          ..flushMicrotasks();

        expect(emissions, hasLength(1));
        expect(
          settle(async, database.userDao.getUserById('u1'))?.status,
          'idle',
        );
        unawaited(sub.cancel());
        batcher.dispose();
      });
    });

    test(
      'mobile-only and custom-status-only changes are not dropped as unchanged',
      () async {
        final FluxerDatabase database = await seededDatabase([
          UsersCompanion.insert(
            id: 'u1',
            username: 'u1',
          ).copyWith(status: const Value('online')),
          UsersCompanion.insert(
            id: 'u2',
            username: 'u2',
          ).copyWith(status: const Value('online')),
        ]);

        fakeAsync((FakeAsync async) {
          final PresenceUpdateBatcher batcher =
              PresenceUpdateBatcher(database: database, currentUserId: 'self')
                ..enqueue(userId: 'u1', status: 'online', mobile: true)
                ..enqueue(userId: 'u2', status: 'online', customStatus: 'brb');
          async
            ..elapse(pastFlush)
            ..flushMicrotasks();

          final User? u1 = settle(async, database.userDao.getUserById('u1'));
          final User? u2 = settle(async, database.userDao.getUserById('u2'));
          expect(u1?.mobile, isTrue);
          expect(u2?.customStatus, 'brb');
          batcher.dispose();
        });
      },
    );

    test(
      'a stale remembered value cannot suppress a write after another path changed the row',
      () async {
        final FluxerDatabase database = await seededDatabase([
          UsersCompanion.insert(
            id: 'u1',
            username: 'u1',
          ).copyWith(status: const Value('online')),
        ]);

        fakeAsync((FakeAsync async) {
          final PresenceUpdateBatcher batcher = PresenceUpdateBatcher(
            database: database,
            currentUserId: 'self',
          )..enqueue(userId: 'u1', status: 'online');
          async
            ..elapse(pastFlush)
            ..flushMicrotasks();
          unawaited(
            database.userDao.upsertUser(
              UsersCompanion.insert(
                id: 'u1',
                username: 'u1',
              ).copyWith(status: const Value('dnd')),
            ),
          );
          async.flushMicrotasks();
          batcher.enqueue(userId: 'u1', status: 'online');
          async
            ..elapse(pastFlush)
            ..flushMicrotasks();

          expect(
            settle(async, database.userDao.getUserById('u1'))?.status,
            'online',
          );
          batcher.dispose();
        });
      },
    );
  });
}
