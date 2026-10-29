import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/core/push/unified_push/unified_push_account_index.dart';
import 'package:fluxer_app/core/push/unified_push/unified_push_instance_id.dart';

void main() {
  group('unifiedPushInstanceIdForApiBase', () {
    test('matches equivalent spellings of the same server', () {
      final String slashed = unifiedPushInstanceIdForApiBase(
        'https://fluxer.com/api/v1/',
      );
      final String plain = unifiedPushInstanceIdForApiBase(
        'https://fluxer.com/api/v1',
      );
      expect(slashed, plain);
      expect(slashed, isNotEmpty);
    });

    test('differs across servers', () {
      expect(
        unifiedPushInstanceIdForApiBase('https://fluxer.com/api/v1'),
        isNot(unifiedPushInstanceIdForApiBase('https://example.com/api/v1')),
      );
    });
  });

  group('soleUnifiedPushUserId', () {
    test('returns the only account on that server', () {
      expect(
        soleUnifiedPushUserId(
          instanceId: unifiedPushInstanceIdForApiBase(
            'https://example.com/api/v1',
          ),
          accounts: const <UnifiedPushStoredAccount>[
            UnifiedPushStoredAccount(
              userId: 'a',
              apiBaseUrl: 'https://fluxer.com/api/v1',
            ),
            UnifiedPushStoredAccount(
              userId: 'b',
              apiBaseUrl: 'https://example.com/api/v1',
            ),
          ],
        ),
        'b',
      );
    });

    test('does not guess when two accounts share a server', () {
      expect(
        soleUnifiedPushUserId(
          instanceId: unifiedPushInstanceIdForApiBase(
            'https://fluxer.com/api/v1',
          ),
          accounts: const <UnifiedPushStoredAccount>[
            UnifiedPushStoredAccount(
              userId: 'a',
              apiBaseUrl: 'https://fluxer.com/api/v1',
            ),
            UnifiedPushStoredAccount(
              userId: 'b',
              apiBaseUrl: 'https://fluxer.com/api/v1/',
            ),
          ],
        ),
        isNull,
      );
    });
  });
}
