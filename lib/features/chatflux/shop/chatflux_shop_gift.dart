// ChatFlux Shop: send an item to a friend, and show gifts you received.

import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxer_app/core/api/fluxer_client_provider.dart';
import 'package:fluxer_app/core/media/fluxer_media_url.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';
import 'package:fluxer_app/features/friends/domain/friend.dart';
import 'package:fluxer_app/features/friends/providers/friend_providers.dart';

const Color _kCard = Color(0xFF1F2024);
const Color _kCardBorder = Color(0xFF2E3036);
const Color _kMuted = Color(0xFFA1A1AA);
const Color _kBrand = Color(0xFF5865F2);
const Color _kError = Color(0xFFFCA5A5);

String _giftErrorText(BuildContext c, Object error) {
  final String code = error is ChatFluxShopException ? error.code : '';
  return switch (code) {
    'not_enough_coins' => chatFluxTr(
      c,
      'Nincs elég Cicaérméd ehhez.',
      "You don't have enough Cat Coins for this.",
    ),
    'recipient_owns' => chatFluxTr(
      c,
      'Neki ez már megvan.',
      'They already own this.',
    ),
    'gift_self' => chatFluxTr(
      c,
      'Magadnak nem küldhetsz ajándékot.',
      "You can't gift yourself.",
    ),
    'gift_bot' => chatFluxTr(
      c,
      'Botnak nem küldhetsz ajándékot.',
      "You can't gift a bot.",
    ),
    'unknown_user' ||
    'bad_user' => chatFluxTr(c, 'Nincs ilyen felhasználó.', 'No such user.'),
    'unauthorized' => chatFluxTr(
      c,
      'Jelentkezz be újra.',
      'Please log in again.',
    ),
    _ => chatFluxTr(
      c,
      'Most nem sikerült. Próbáld újra később.',
      "That didn't work. Try again later.",
    ),
  };
}

/// Opens the friend picker for [item]. Returns the recipient's name on success.
Future<String?> showChatFluxGiftSheet(
  BuildContext context,
  ChatFluxItem item,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: _kCard,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (BuildContext _) => _GiftSheet(item: item),
);

class _Recipient {
  const _Recipient(this.id, this.name);

  final String id;
  final String name;
}

class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet({required this.item});

  final ChatFluxItem item;

  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  final TextEditingController _search = TextEditingController();
  _Recipient? _selected;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final _Recipient? to = _selected;
    final String? token = ref.read(fluxerAuthTokenProvider);
    if (to == null || token == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String? name = await ChatFluxShopStore.instance.gift(
        token,
        widget.item.sku,
        to.id,
      );
      if (mounted) {
        Navigator.of(context).pop(name ?? to.name);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _giftErrorText(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Friend> friends =
        (ref.watch(friendsListProvider).value ?? const <Friend>[])
            .where((Friend f) => f.friendStatus == FriendStatus.accepted)
            .toList()
          ..sort(
            (Friend a, Friend b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
    final String query = _search.text.trim();
    final String lower = query.toLowerCase();
    final List<Friend> shown = friends
        .where(
          (Friend f) =>
              lower.isEmpty ||
              f.displayName.toLowerCase().contains(lower) ||
              f.username.toLowerCase().contains(lower) ||
              f.id == query,
        )
        .toList();
    final bool queryIsId = RegExp(r'^\d{5,20}$').hasMatch(query);
    final bool idListed = shown.any((Friend f) => f.id == query);
    final int price = widget.item.price;
    final int balance = ChatFluxShopStore.instance.me.value?.balance ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _kCardBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  chatFluxTr(context, 'Ajándék küldése', 'Send as a gift'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chatFluxTr(
                    context,
                    '${chatFluxLocalize(context, widget.item.name)} – legfeljebb $price Cicaérme. '
                        'Ha neki már megvan egy része, kevesebbe kerül.',
                    '${chatFluxLocalize(context, widget.item.name)} – up to $price Cat Coins. '
                        'If they already own part of it, it costs less.',
                  ),
                  style: const TextStyle(color: _kMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF141518),
                    prefixIcon: const Icon(Icons.search, color: _kMuted),
                    hintText: chatFluxTr(
                      context,
                      'Barát neve vagy felhasználó ID',
                      'Friend name or user ID',
                    ),
                    hintStyle: const TextStyle(color: _kMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      if (queryIsId && !idListed)
                        _RecipientTile(
                          title: chatFluxTr(
                            context,
                            'Felhasználó ID: $query',
                            'User ID: $query',
                          ),
                          avatarUrl: null,
                          selected: _selected?.id == query,
                          onTap: () => setState(
                            () => _selected = _Recipient(query, query),
                          ),
                        ),
                      for (final Friend f in shown)
                        _RecipientTile(
                          title: f.displayName,
                          subtitle: f.username,
                          avatarUrl:
                              FluxerMediaUrl.userAvatar(
                                userId: f.id,
                                hash: f.avatar,
                              ) ??
                              FluxerMediaUrl.defaultAvatar(userId: f.id),
                          selected: _selected?.id == f.id,
                          onTap: () => setState(
                            () => _selected = _Recipient(f.id, f.displayName),
                          ),
                        ),
                      if (shown.isEmpty && !queryIsId)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            friends.isEmpty
                                ? chatFluxTr(
                                    context,
                                    'Még nincsenek barátaid. Beírhatod valakinek a felhasználó ID-ját is.',
                                    'You have no friends yet. You can also type a user ID.',
                                  )
                                : chatFluxTr(
                                    context,
                                    'Nincs találat.',
                                    'No matches.',
                                  ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _kMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _kError),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _selected == null || _busy || balance <= 0
                      ? null
                      : () => unawaited(_send()),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard_rounded),
                  label: Text(
                    _selected == null
                        ? chatFluxTr(
                            context,
                            'Válaszd ki, kinek küldöd',
                            'Pick who gets it',
                          )
                        : chatFluxTr(
                            context,
                            'Elküldöm neki: ${_selected!.name}',
                            'Send to ${_selected!.name}',
                          ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientTile extends StatelessWidget {
  const _RecipientTile({
    required this.title,
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? const Color(0x335865F2) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? _kBrand : Colors.transparent),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: ClipOval(
          child: avatarUrl == null
              ? Container(
                  width: 34,
                  height: 34,
                  color: const Color(0xFF4B4F58),
                  child: const Icon(Icons.person, color: Colors.white70),
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 34,
                    height: 34,
                    color: const Color(0xFF4B4F58),
                  ),
                ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kMuted, fontSize: 12),
              ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: _kBrand)
            : null,
      ),
    ),
  );
}

/// "You got a gift" card at the top of the shop. Hidden when there is nothing new.
class ChatFluxGiftNotice extends ConsumerWidget {
  const ChatFluxGiftNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChatFluxShopStore store = ChatFluxShopStore.instance;
    return ValueListenableBuilder<ChatFluxMe?>(
      valueListenable: store.me,
      builder: (BuildContext context, ChatFluxMe? me, Widget? _) {
        final List<ChatFluxGift> gifts = me?.gifts ?? const <ChatFluxGift>[];
        if (gifts.isEmpty) {
          return const SizedBox.shrink();
        }
        final ChatFluxCatalog? catalog = store.catalog.value;
        String line(ChatFluxGift g) {
          final String from =
              g.fromName ?? chatFluxTr(context, 'Valaki', 'Someone');
          final List<String> what = <String>[
            if (g.sku case final String sku)
              if (catalog?.item(sku) case final ChatFluxItem item)
                chatFluxLocalize(context, item.name)
              else
                sku,
            if (g.coins != null)
              chatFluxTr(
                context,
                '${g.coins} Cicaérme',
                '${g.coins} Cat Coins',
              ),
          ];
          return '$from → ${what.join(', ')}';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF3B2A6B), Color(0xFF5B2A4A)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.card_giftcard_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatFluxTr(
                        context,
                        'Ajándékot kaptál!',
                        'You received a gift!',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ChatFluxGift g in gifts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line(g),
                    style: const TextStyle(color: Color(0xFFE4E4E7)),
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final String? token = ref.read(fluxerAuthTokenProvider);
                    if (token != null) {
                      unawaited(
                        store.markGiftsSeen(token).catchError((Object _) {}),
                      );
                    }
                  },
                  child: Text(chatFluxTr(context, 'Köszönöm!', 'Thanks!')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
