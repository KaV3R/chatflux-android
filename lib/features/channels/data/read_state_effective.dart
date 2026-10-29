import 'package:flutter/foundation.dart';
import 'package:fluxer_app/features/channels/data/read_state_utils.dart';

@immutable
class ReadStateEffectiveFields {
  const ReadStateEffectiveFields({
    required this.lastMessageId,
    required this.mentionCount,
  });

  final String? lastMessageId;
  final int mentionCount;
}

ReadStateEffectiveFields simulateUnreadIntents({
  required String? lastMessageId,
  required int mentionCount,
  required bool isDm,
  required List<UnreadIntentFields> intents,
}) {
  var workingLastMessageId = lastMessageId;
  var workingMentionCount = mentionCount;

  for (final UnreadIntentFields intent in intents) {
    if (workingLastMessageId != null &&
        compareSnowflakeIds(intent.messageId, workingLastMessageId) <= 0) {
      continue;
    }
    if (workingLastMessageId == null &&
        !isDm &&
        intent.seedAckCandidate != null) {
      workingLastMessageId = intent.seedAckCandidate;
    }
    if (intent.shouldMention) {
      workingMentionCount += 1;
    }
  }

  return ReadStateEffectiveFields(
    lastMessageId: workingLastMessageId,
    mentionCount: workingMentionCount,
  );
}

@immutable
class UnreadIntentFields {
  const UnreadIntentFields({
    required this.messageId,
    required this.shouldMention,
    required this.seedAckCandidate,
  });

  final String messageId;
  final bool shouldMention;
  final String? seedAckCandidate;
}
