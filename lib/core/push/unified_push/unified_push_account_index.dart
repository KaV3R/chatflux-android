import 'package:fluxer_app/core/push/unified_push/unified_push_instance_id.dart';
import 'package:fluxer_app/features/auth/data/auth_token_storage.dart';

class UnifiedPushStoredAccount {
  const UnifiedPushStoredAccount({
    required this.userId,
    required this.apiBaseUrl,
  });

  final String userId;
  final String apiBaseUrl;

  String get instanceId => unifiedPushInstanceIdForApiBase(apiBaseUrl);
}

String? soleUnifiedPushUserId({
  required String instanceId,
  required Iterable<UnifiedPushStoredAccount> accounts,
}) {
  if (instanceId.isEmpty) {
    return null;
  }
  String? match;
  for (final UnifiedPushStoredAccount account in accounts) {
    if (account.instanceId != instanceId) {
      continue;
    }
    if (match != null && match != account.userId) {
      return null;
    }
    match = account.userId;
  }
  return match;
}

Future<String?> unifiedPushTargetUserForInstance(String instanceId) async {
  final List<({String userId, String apiBaseUrl})> stored =
      await SecureAuthTokenStorage().readAccountApiBases();
  return soleUnifiedPushUserId(
    instanceId: instanceId,
    accounts: <UnifiedPushStoredAccount>[
      for (final ({String userId, String apiBaseUrl}) account in stored)
        UnifiedPushStoredAccount(
          userId: account.userId,
          apiBaseUrl: account.apiBaseUrl,
        ),
    ],
  );
}
