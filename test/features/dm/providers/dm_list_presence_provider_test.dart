import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/core/database/fluxer_database.dart';
import 'package:fluxer_app/core/providers/database_provider.dart';
import 'package:fluxer_app/features/channels/domain/channel.dart';
import 'package:fluxer_app/features/dm/domain/dm_conversation.dart';
import 'package:fluxer_app/features/dm/providers/dm_list_presence_provider.dart';
import 'package:fluxer_app/features/dm/providers/dm_view_model.dart';

import '../../../helpers/open_test_database.dart';

void main() {
  group('dmListRecipientUserIdsKeyProvider', () {
    test(
      'ignores last-message updates when the recipient set is unchanged',
      () {
        DmViewState stateWithMessage(String message) {
          return DmViewState(
            conversations: [
              DmConversation(
                id: '100',
                type: ChannelType.dm.wireValue,
                recipientId: '200',
                recipientName: 'Monty',
                lastMessage: message,
                lastMessageTime: DateTime(2026),
              ),
            ],
            friendsList: const [],
            activeTab: FriendsTab.online,
            searchQuery: '',
          );
        }

        final ProviderContainer before = ProviderContainer(
          overrides: [
            dmViewModelProvider.overrideWithValue(stateWithMessage('Hello')),
          ],
        );
        final ProviderContainer after = ProviderContainer(
          overrides: [
            dmViewModelProvider.overrideWithValue(
              stateWithMessage('Updated preview text'),
            ),
          ],
        );
        addTearDown(before.dispose);
        addTearDown(after.dispose);

        expect(
          before.read(dmListRecipientUserIdsKeyProvider),
          after.read(dmListRecipientUserIdsKeyProvider),
        );
      },
    );

    test('keys only one-to-one recipients', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          dmViewModelProvider.overrideWithValue(
            DmViewState(
              conversations: [
                DmConversation(
                  id: 'group',
                  type: ChannelType.groupDm.wireValue,
                  recipientId: '200',
                  recipientName: 'Monty',
                  lastMessage: '',
                  lastMessageTime: DateTime(2026),
                  remoteRecipientIds: const ['201', '202'],
                ),
                DmConversation(
                  id: 'notes',
                  type: ChannelType.dmPersonalNotes.wireValue,
                  recipientId: '300',
                  recipientName: 'Notes',
                  lastMessage: '',
                  lastMessageTime: DateTime(2026),
                ),
                DmConversation(
                  id: 'dm',
                  type: ChannelType.dm.wireValue,
                  recipientId: '400',
                  recipientName: 'Alex',
                  lastMessage: '',
                  lastMessageTime: DateTime(2026),
                ),
              ],
              friendsList: const [],
              activeTab: FriendsTab.online,
              searchQuery: '',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(dmListRecipientUserIdsKeyProvider), '400');
    });
  });

  group('dmListRecipientRowDataProvider', () {
    test(
      'keeps the last custom status after the last listener leaves, so '
      're-entering the DM list does not pop it in from AsyncLoading',
      () async {
        final FluxerDatabase database = openTestDatabase();
        await database.userDao.upsertUser(
          UsersCompanion.insert(
            id: 'u1',
            username: 'u1',
          ).copyWith(customStatus: const Value('brb')),
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [
            fluxerDatabaseProvider.overrideWithValue(database),
            dmListRecipientUserIdsKeyProvider.overrideWithValue('u1'),
          ],
        );
        addTearDown(container.dispose);

        final ProviderSubscription<Object?> firstVisit = container.listen(
          dmListRecipientRowDataProvider,
          (_, _) {},
        );
        await container.read(dmListRecipientRowDataProvider.future);
        firstVisit.close();
        await pumpEventQueue();

        expect(
          container
              .read(dmListRecipientRowDataProvider)
              .value?['u1']
              ?.customStatus,
          'brb',
        );
      },
    );
  });
}
