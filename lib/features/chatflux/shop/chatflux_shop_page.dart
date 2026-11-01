// ChatFlux Shop page: buy and wear profile cosmetics.

import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxer_app/core/api/fluxer_client_provider.dart';
import 'package:fluxer_app/core/database/fluxer_database.dart' as db;
import 'package:fluxer_app/core/media/fluxer_media_url.dart';
import 'package:fluxer_app/core/router/fluxer_router.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_cosmetics.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_gift.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';
import 'package:fluxer_app/features/profile/providers/user_presence_provider.dart';

const Color _kBg = Color(0xFF17181B);
const Color _kCard = Color(0xFF1F2024);
const Color _kCardBorder = Color(0xFF2E3036);
const Color _kMuted = Color(0xFFA1A1AA);
const Color _kCoin = Color(0xFFFBBF24);
const Color _kBrand = Color(0xFF5865F2);

String _formatCoins(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(' ');
    }
    out.write(digits[i]);
  }
  return out.toString();
}

String _typeLabel(BuildContext c, String type, {bool plural = false}) =>
    switch (type) {
      'decoration' =>
        plural
            ? chatFluxTr(c, 'Avatar díszek', 'Avatar Decorations')
            : chatFluxTr(c, 'Avatar dísz', 'Avatar Decoration'),
      'nameplate' =>
        plural
            ? chatFluxTr(c, 'Névtáblák', 'Nameplates')
            : chatFluxTr(c, 'Névtábla', 'Nameplate'),
      'effect' =>
        plural
            ? chatFluxTr(c, 'Profil effektek', 'Profile Effects')
            : chatFluxTr(c, 'Profil effekt', 'Profile Effect'),
      'frame' =>
        plural
            ? chatFluxTr(c, 'Profilkeretek', 'Profile Frames')
            : chatFluxTr(c, 'Profilkeret', 'Profile Frame'),
      _ =>
        plural
            ? chatFluxTr(c, 'Csomagok', 'Bundles')
            : chatFluxTr(c, 'Csomag', 'Bundle'),
    };

String _errorText(BuildContext c, Object? error) {
  if (error is ChatFluxShopException) {
    return switch (error.code) {
      'not_enough_coins' => chatFluxTr(
        c,
        'Nincs elég Cicaérméd ehhez.',
        "You don't have enough Cat Coins for this.",
      ),
      'already_owned' => chatFluxTr(
        c,
        'Ez már a tiéd.',
        'You already own this.',
      ),
      'not_owned' => chatFluxTr(
        c,
        'Ezt még nem vetted meg.',
        "You don't own this yet.",
      ),
      'unauthorized' => chatFluxTr(
        c,
        'Jelentkezz be újra.',
        'Please log in again.',
      ),
      _ => chatFluxTr(
        c,
        'A bolt most nem érhető el. Próbáld újra később.',
        'The shop is unavailable right now. Try again later.',
      ),
    };
  }
  return chatFluxTr(
    c,
    'A bolt most nem érhető el. Próbáld újra később.',
    'The shop is unavailable right now. Try again later.',
  );
}

class _Me {
  const _Me(this.avatarUrl, this.name);

  final String? avatarUrl;
  final String name;
}

_Me _watchMe(WidgetRef ref) {
  final String? userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const _Me(null, 'ChatFlux');
  }
  final db.User? user = watchLastKnownUserPresence(ref, userId);
  return _Me(
    FluxerMediaUrl.userAvatar(userId: userId, hash: user?.avatar) ??
        FluxerMediaUrl.defaultAvatar(userId: userId),
    user?.globalName ?? user?.username ?? 'ChatFlux',
  );
}

class ChatFluxShopPage extends ConsumerStatefulWidget {
  const ChatFluxShopPage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const ChatFluxShopPage(),
        ),
      );

  @override
  ConsumerState<ChatFluxShopPage> createState() => _ChatFluxShopPageState();
}

class _ChatFluxShopPageState extends ConsumerState<ChatFluxShopPage> {
  final ChatFluxShopStore _store = ChatFluxShopStore.instance;
  Object? _catalogError;
  bool _meFailed = false;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _catalogError = null);
    try {
      await _store.loadCatalog();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _catalogError = error);
      }
    }
    final String? token = ref.read(fluxerAuthTokenProvider);
    if (token == null) {
      return;
    }
    try {
      await _store.loadMe(token);
      if (mounted) {
        setState(() => _meFailed = false);
      }
    } on Object {
      if (mounted) {
        setState(() => _meFailed = true);
      }
    }
  }

  void _openItem(ChatFluxItem item) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _kCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext _) => _ItemSheet(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Row(
            children: <Widget>[
              Icon(Icons.storefront_rounded, size: 22),
              SizedBox(width: 8),
              Text('Shop'),
            ],
          ),
          actions: <Widget>[
            ValueListenableBuilder<ChatFluxMe?>(
              valueListenable: _store.me,
              builder: (BuildContext _, ChatFluxMe? me, Widget? _) =>
                  _BalancePill(balance: me?.balance),
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: _kMuted,
            dividerColor: _kCardBorder,
            tabs: <Widget>[
              Tab(text: chatFluxTr(context, 'Kiemelt', 'Featured')),
              Tab(text: chatFluxTr(context, 'Böngészés', 'Browse')),
              Tab(text: chatFluxTr(context, 'Gyűjteményem', 'My collection')),
            ],
          ),
        ),
        body: ValueListenableBuilder<ChatFluxCatalog?>(
          valueListenable: _store.catalog,
          builder: (BuildContext context, ChatFluxCatalog? catalog, Widget? _) {
            if (catalog == null) {
              return Center(
                child: _catalogError == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              _errorText(context, _catalogError),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _kMuted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => unawaited(_load()),
                              child: Text(
                                chatFluxTr(context, 'Újrapróbálom', 'Retry'),
                              ),
                            ),
                          ],
                        ),
                      ),
              );
            }
            return ValueListenableBuilder<ChatFluxMe?>(
              valueListenable: _store.me,
              builder: (BuildContext context, ChatFluxMe? _, Widget? _) =>
                  TabBarView(
                    children: <Widget>[
                      _featured(context, catalog),
                      _browse(context, catalog),
                      _owned(context, catalog),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }

  Widget _notice(BuildContext context) => !_meFailed
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            chatFluxTr(
              context,
              'Nem sikerült betölteni a fiókodat a boltban, ezért most csak nézelődni tudsz.',
              'Could not load your shop account, so you can only browse for now.',
            ),
            style: const TextStyle(color: _kMuted, fontSize: 13),
          ),
        );

  Widget _grid(List<ChatFluxItem> items) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext _, int index) =>
            _ItemCard(item: items[index], onTap: _openItem),
        childCount: items.length,
      ),
    ),
  );

  Widget _sectionTitle(String text, {Widget? trailing}) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );

  Widget _featured(BuildContext context, ChatFluxCatalog catalog) {
    final ChatFluxCollection? collection = catalog.collections.isEmpty
        ? null
        : catalog.collections.firstWhere(
            (ChatFluxCollection c) => c.featured,
            orElse: () => catalog.collections.first,
          );
    final List<ChatFluxItem> featured = catalog.items
        .where((ChatFluxItem i) => i.featured && !i.isBundle)
        .toList();
    final List<ChatFluxItem> bundles = catalog.items
        .where((ChatFluxItem i) => i.isBundle)
        .toList();
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _notice(context)),
        const SliverToBoxAdapter(child: ChatFluxGiftNotice()),
        if (collection != null)
          SliverToBoxAdapter(
            child: _Hero(
              collection: collection,
              onShop: () => DefaultTabController.of(context).animateTo(1),
            ),
          ),
        if (featured.isNotEmpty) ...<Widget>[
          _sectionTitle(chatFluxTr(context, 'Kiemelt', 'Featured')),
          _grid(featured),
        ],
        if (bundles.isNotEmpty) ...<Widget>[
          _sectionTitle(_typeLabel(context, 'bundle', plural: true)),
          _grid(bundles),
        ],
        for (final ChatFluxCollection other in catalog.collections)
          if (other.id != collection?.id)
            if (catalog.items
                    .where(
                      (ChatFluxItem i) =>
                          i.collection == other.id && !i.isBundle,
                    )
                    .toList()
                case final List<ChatFluxItem> items
                when items.isNotEmpty) ...<Widget>[
              _sectionTitle(chatFluxLocalize(context, other.name)),
              _grid(items),
            ],
        for (final String type in kChatFluxShopSlots) ...<Widget>[
          _sectionTitle(
            _typeLabel(context, type, plural: true),
            trailing: TextButton(
              onPressed: () {
                setState(() => _typeFilter = type);
                DefaultTabController.of(context).animateTo(1);
              },
              child: Text(
                chatFluxTr(context, 'Mind', 'See all'),
                style: const TextStyle(color: _kMuted),
              ),
            ),
          ),
          _grid(
            catalog.items
                .where((ChatFluxItem i) => i.type == type)
                .take(4)
                .toList(),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _browse(BuildContext context, ChatFluxCatalog catalog) {
    final List<ChatFluxItem> items = catalog.items
        .where((ChatFluxItem i) => _typeFilter == null || i.type == _typeFilter)
        .toList();
    final List<String> types = <String>[...kChatFluxShopSlots, 'bundle'];
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              children: <Widget>[
                _FilterChip(
                  label: chatFluxTr(context, 'Mind', 'All'),
                  selected: _typeFilter == null,
                  onTap: () => setState(() => _typeFilter = null),
                ),
                for (final String type in types)
                  _FilterChip(
                    label: _typeLabel(context, type, plural: true),
                    selected: _typeFilter == type,
                    onTap: () => setState(() => _typeFilter = type),
                  ),
              ],
            ),
          ),
        ),
        _sectionTitle(
          '${_typeFilter == null ? chatFluxTr(context, 'Minden termék', 'All items') : _typeLabel(context, _typeFilter!, plural: true)} (${items.length})',
        ),
        _grid(items),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _owned(BuildContext context, ChatFluxCatalog catalog) {
    final ChatFluxMe? me = _store.me.value;
    final List<ChatFluxItem> owned = catalog.items
        .where((ChatFluxItem i) => !i.isBundle && _store.owns(i))
        .toList();
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _notice(context)),
        const SliverToBoxAdapter(child: ChatFluxGiftNotice()),
        _sectionTitle(
          chatFluxTr(context, 'Amit most viselsz', 'Currently wearing'),
        ),
        SliverList.list(
          children: <Widget>[
            for (final String slot in kChatFluxShopSlots)
              Builder(
                builder: (BuildContext context) {
                  final String? sku = me?.equipped[slot];
                  final ChatFluxItem? item = sku == null
                      ? null
                      : catalog.item(sku);
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _typeLabel(context, slot).toUpperCase(),
                                style: const TextStyle(
                                  color: _kMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item == null
                                    ? chatFluxTr(context, 'Nincs', 'None')
                                    : chatFluxLocalize(context, item.name),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (item != null)
                          TextButton(
                            onPressed: () => unawaited(_unequip(slot)),
                            child: Text(
                              chatFluxTr(context, 'Leveszem', 'Remove'),
                              style: const TextStyle(color: _kMuted),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        _sectionTitle(
          '${chatFluxTr(context, 'Gyűjteményem', 'My collection')} (${owned.length})',
        ),
        if (owned.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                chatFluxTr(
                  context,
                  'Még nincs semmid. Nézz körül a boltban!',
                  "You don't own anything yet. Take a look around the shop!",
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted),
              ),
            ),
          )
        else
          _grid(owned),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Future<void> _unequip(String slot) async {
    final String? token = ref.read(fluxerAuthTokenProvider);
    if (token == null) {
      return;
    }
    try {
      await _store.equip(token, slot, null);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(context, error))));
      }
    }
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.monetization_on_rounded, color: _kCoin, size: 18),
        const SizedBox(width: 6),
        Text(
          balance == null ? '–' : _formatCoins(balance!),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kBrand : Colors.transparent,
          border: Border.all(color: selected ? _kBrand : _kCardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.collection, required this.onShop});

  final ChatFluxCollection collection;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final String? banner = chatFluxAssetUrl(collection.banner);
    return Container(
      height: 230,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0618),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (banner != null)
            CachedNetworkImage(
              imageUrl: banner,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xE607030F), Color(0x0007030F)],
                stops: <double>[0.15, 0.85],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (collection.tagline != null)
                  Text(
                    chatFluxLocalize(context, collection.tagline).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFF7A18),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 230,
                  child: Text(
                    chatFluxLocalize(context, collection.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: onShop,
                  child: Text(
                    chatFluxTr(
                      context,
                      'Kollekció megtekintése',
                      'Shop the collection',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final ChatFluxItem item;
  final void Function(ChatFluxItem item) onTap;

  @override
  Widget build(BuildContext context) {
    final ChatFluxShopStore store = ChatFluxShopStore.instance;
    final bool owned = store.owns(item);
    final bool equipped = store.isEquipped(item);
    return GestureDetector(
      onTap: () => onTap(item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _kCard,
          border: Border.all(color: _kCardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: <Color>[Color(0xFF2B2D33), _kCard],
                        ),
                      ),
                      child: Center(child: _ItemPreview(item: item)),
                    ),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Tag(
                        text: chatFluxLocalize(context, item.badge),
                        background: Colors.white,
                        foreground: Colors.black,
                      ),
                    ),
                  if (owned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Tag(
                        text: equipped
                            ? chatFluxTr(context, 'Viseled', 'Equipped')
                            : chatFluxTr(context, 'Megvéve', 'Owned'),
                        background: equipped
                            ? const Color(0xFF16A34A)
                            : const Color(0x99000000),
                        foreground: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    chatFluxLocalize(context, item.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (owned)
                    Text(
                      _typeLabel(context, item.type),
                      style: const TextStyle(color: _kMuted, fontSize: 12),
                    )
                  else
                    _PriceRow(item: item, fontSize: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, this.fontSize = 14});

  final ChatFluxItem item;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ChatFluxShopStore store = ChatFluxShopStore.instance;
    final int price = store.priceFor(item);
    final int pieces = store.piecesPrice(item);
    final bool discount = item.isBundle && pieces > price;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      children: <Widget>[
        Icon(Icons.monetization_on_rounded, color: _kCoin, size: fontSize + 3),
        Text(
          _formatCoins(price),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
        if (discount) ...<Widget>[
          Text(
            _formatCoins(pieces),
            style: TextStyle(
              color: _kMuted,
              decoration: TextDecoration.lineThrough,
              fontSize: fontSize - 1,
            ),
          ),
          Text(
            '-${((1 - price / pieces) * 100).round()}%',
            style: TextStyle(
              color: const Color(0xFF4ADE80),
              fontSize: fontSize - 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemPreview extends ConsumerWidget {
  const _ItemPreview({required this.item, this.large = false});

  final ChatFluxItem item;
  final bool large;

  ChatFluxWorn _bundleWorn() {
    final ChatFluxCatalog? catalog = ChatFluxShopStore.instance.catalog.value;
    final Map<String, ChatFluxRender> slots = <String, ChatFluxRender>{};
    for (final String sku in item.contains) {
      final ChatFluxItem? piece = catalog?.item(sku);
      if (piece != null && !piece.isBundle) {
        slots[piece.type] = piece.render;
      }
    }
    return ChatFluxWorn(slots);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _Me me = _watchMe(ref);
    switch (item.type) {
      case 'decoration':
        return _avatar(me, large ? 150 : 76, item.render);
      case 'nameplate':
        return _nameplateRows(me, item.render);
      case 'effect':
        return _miniCard(
          me,
          ChatFluxWorn(<String, ChatFluxRender>{'effect': item.render}),
        );
      case 'frame':
        return _miniCard(
          me,
          ChatFluxWorn(<String, ChatFluxRender>{'frame': item.render}),
        );
      default:
        return _miniCard(me, _bundleWorn());
    }
  }

  Widget _avatarImage(_Me me, double size) => ClipOval(
    child: me.avatarUrl == null
        ? Container(width: size, height: size, color: const Color(0xFF4B4F58))
        : CachedNetworkImage(
            imageUrl: me.avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: size,
              height: size,
              color: const Color(0xFF4B4F58),
            ),
          ),
  );

  Widget _avatar(_Me me, double size, ChatFluxRender? decoration) =>
      ChatFluxDecorationOverlay(
        render: decoration,
        size: size,
        child: _avatarImage(me, size),
      );

  Widget _skeleton(double width, {double height = 8}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFF4B4F58),
      borderRadius: BorderRadius.circular(99),
    ),
  );

  Widget _nameplateRows(_Me me, ChatFluxRender render) {
    final double rowHeight = large ? 52 : 38;
    final double avatar = large ? 34 : 24;
    Widget fadedRow(double width) => Opacity(
      opacity: 0.35,
      child: SizedBox(
        height: rowHeight,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 8),
            Container(
              width: avatar,
              height: avatar,
              decoration: const BoxDecoration(
                color: Color(0xFF4B4F58),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            _skeleton(width),
          ],
        ),
      ),
    );
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          fadedRow(50),
          SizedBox(
            height: rowHeight,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ChatFluxNameplateBackground(render: render),
                ),
                Row(
                  children: <Widget>[
                    const SizedBox(width: 8),
                    _avatarImage(me, avatar),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        me.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: large ? 16 : 13,
                          shadows: const <Shadow>[
                            Shadow(blurRadius: 3, color: Color(0x99000000)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          fadedRow(70),
        ],
      ),
    );
  }

  Widget _miniCard(_Me me, ChatFluxWorn worn) {
    final double width = large ? 230 : 104;
    final double height = large ? 300 : 124;
    final double avatar = width * 0.3;
    final Color border = worn.frame?.parsedColor ?? const Color(0xFF3F4147);
    final String? frameBottom = chatFluxAssetUrl(worn.frame?.bottom);
    final String? frameTop = chatFluxAssetUrl(worn.frame?.top);
    // Frame art is 340 wide for a 300 wide card.
    final double frameWidth = width * 340 / 300;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF232428),
                border: Border.all(color: border, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: height * 0.28,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Color(0xFF4C3A75),
                              Color(0xFF2C2245),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: avatar * 0.62),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              me.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: large ? 17 : 10,
                              ),
                            ),
                            SizedBox(height: large ? 10 : 5),
                            if (worn.nameplate != null)
                              SizedBox(
                                height: large ? 34 : 18,
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: ChatFluxNameplateBackground(
                                        render: worn.nameplate,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: _skeleton(width * 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              _skeleton(width * 0.5, height: large ? 10 : 6),
                            SizedBox(height: large ? 10 : 5),
                            _skeleton(width * 0.75, height: large ? 10 : 6),
                            SizedBox(height: large ? 10 : 5),
                            _skeleton(width * 0.6, height: large ? 10 : 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (worn.effect != null)
                    Positioned.fill(
                      child: ChatFluxEffectLayer(render: worn.effect),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: width * 0.08,
            top: height * 0.28 - avatar / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF232428), width: 3),
              ),
              child: _avatar(me, avatar, worn.decoration),
            ),
          ),
          if (frameTop != null)
            Positioned(
              left: (width - frameWidth) / 2,
              top: -frameWidth * 110 / 340 * 40 / 110,
              width: frameWidth,
              height: frameWidth * 110 / 340,
              child: IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: frameTop,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          if (frameBottom != null)
            Positioned(
              left: (width - frameWidth) / 2,
              bottom: -frameWidth * 70 / 340 * 40 / 70,
              width: frameWidth,
              height: frameWidth * 70 / 340,
              child: IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: frameBottom,
                  fit: BoxFit.fill,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.item});

  final ChatFluxItem item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  String? _error;
  String? _info;

  Future<void> _gift() async {
    setState(() {
      _error = null;
      _info = null;
    });
    final String? name = await showChatFluxGiftSheet(context, widget.item);
    if (name != null && mounted) {
      setState(
        () => _info = chatFluxTr(
          context,
          'Elküldve! $name megkapta az ajándékot. 🎁',
          'Sent! $name received your gift. 🎁',
        ),
      );
    }
  }

  Future<void> _run(Future<void> Function(String token) action) async {
    final String? token = ref.read(fluxerAuthTokenProvider);
    if (token == null) {
      return;
    }
    setState(() => _error = null);
    try {
      await action(token);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = _errorText(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatFluxShopStore store = ChatFluxShopStore.instance;
    final ChatFluxItem item = widget.item;
    return ValueListenableBuilder<ChatFluxMe?>(
      valueListenable: store.me,
      builder: (BuildContext context, ChatFluxMe? me, Widget? _) =>
          ValueListenableBuilder<String?>(
            valueListenable: store.pendingSku,
            builder: (BuildContext context, String? pending, Widget? _) {
              final bool owned = store.owns(item);
              final bool equipped = store.isEquipped(item);
              final bool busy = pending != null;
              final int price = store.priceFor(item);
              final int balance = me?.balance ?? 0;
              Widget action;
              if (me == null) {
                action = Text(
                  _errorText(context, null),
                  style: const TextStyle(color: Color(0xFFFCA5A5)),
                );
              } else if (!owned) {
                action = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBrand,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: busy || balance < price
                          ? null
                          : () => unawaited(
                              _run(
                                (String token) =>
                                    store.purchase(token, item.sku),
                              ),
                            ),
                      icon: const Icon(Icons.monetization_on_rounded),
                      label: Text(
                        chatFluxTr(
                          context,
                          'Megveszem – ${_formatCoins(price)}',
                          'Buy for ${_formatCoins(price)}',
                        ),
                      ),
                    ),
                    if (balance < price)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          chatFluxTr(
                            context,
                            'Még ${_formatCoins(price - balance)} Cicaérme hiányzik.',
                            'You need ${_formatCoins(price - balance)} more Cat Coins.',
                          ),
                          style: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                  ],
                );
              } else if (item.isBundle) {
                action = FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          _run((String token) async {
                            for (final String sku in item.contains) {
                              final ChatFluxItem? piece = store.catalog.value
                                  ?.item(sku);
                              if (piece != null && !piece.isBundle) {
                                await store.equip(token, piece.type, piece.sku);
                              }
                            }
                          }),
                        ),
                  child: Text(
                    chatFluxTr(context, 'Mindet felveszem', 'Equip all'),
                  ),
                );
              } else {
                action = FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: equipped
                        ? const Color(0xFF2E3036)
                        : _kBrand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          _run(
                            (String token) => store.equip(
                              token,
                              item.type,
                              equipped ? null : item.sku,
                            ),
                          ),
                        ),
                  child: Text(
                    equipped
                        ? chatFluxTr(context, 'Leveszem', 'Unequip')
                        : chatFluxTr(context, 'Felveszem', 'Equip'),
                  ),
                );
              }
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
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
                      Container(
                        height: 340,
                        margin: const EdgeInsets.only(top: 12, bottom: 16),
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: <Color>[
                              Color(0xFF2F3138),
                              Color(0xFF141518),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: _ItemPreview(item: item, large: true),
                        ),
                      ),
                      Text(
                        _typeLabel(context, item.type).toUpperCase(),
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chatFluxLocalize(context, item.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.description != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          chatFluxLocalize(context, item.description),
                          style: const TextStyle(
                            color: Color(0xFFD4D4D8),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (item.isBundle) ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final String sku in item.contains)
                              if (store.catalog.value?.item(sku)
                                  case final ChatFluxItem piece)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF26272C),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${store.owns(piece) ? '✓ ' : ''}${chatFluxLocalize(context, piece.name)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                      if (!owned) ...<Widget>[
                        const SizedBox(height: 12),
                        _PriceRow(item: item, fontSize: 18),
                      ],
                      const SizedBox(height: 18),
                      action,
                      if (me != null) ...<Widget>[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _kCardBorder),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: busy ? null : () => unawaited(_gift()),
                          icon: const Icon(Icons.card_giftcard_rounded),
                          label: Text(
                            chatFluxTr(
                              context,
                              'Ajándékba adom valakinek',
                              'Gift to someone',
                            ),
                          ),
                        ),
                      ],
                      if (_info != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _info!,
                            style: const TextStyle(color: Color(0xFF86EFAC)),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFCA5A5)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
