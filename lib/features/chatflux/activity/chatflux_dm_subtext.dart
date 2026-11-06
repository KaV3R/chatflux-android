// ChatFlux: second line of a DM list row. An ongoing call (also when you are in it on
// another device) or the game the other person plays replaces the usual line.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxer_app/core/gateway/providers/gateway_event_providers.dart';
import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/features/chatflux/activity/chatflux_activity.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';
import 'package:fluxer_app/features/dm/domain/dm_conversation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ChatFluxDmSubtext extends ConsumerWidget {
  const ChatFluxDmSubtext({
    required this.conversation,
    required this.style,
    required this.fallback,
    this.showGame = true,
    super.key,
  });

  final DmConversation conversation;
  final TextStyle style;
  final Widget fallback;
  final bool showGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int inCall = ref.watch(
      privateChannelVoiceParticipantCountProvider(conversation.id),
    );
    if (inCall > 0) {
      final Color color = context.colors.statusOnline;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(PhosphorIconsFill.phone, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              chatFluxTr(
                context,
                'Hívásban · $inCall fő',
                'In a call · $inCall',
              ),
              style: style.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    if (conversation.isGroup || !showGame) {
      return fallback;
    }
    return ChatFluxGameActivityLine(
      userId: conversation.recipientId,
      style: style,
      fallback: fallback,
    );
  }
}
