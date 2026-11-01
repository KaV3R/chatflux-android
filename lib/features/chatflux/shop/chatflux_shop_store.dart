// ChatFlux Shop: talks to the shop service next to the server
// (https://chat.catflux.hu/shop-api), which stores bought / worn profile cosmetics.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

const String kChatFluxShopBase = 'https://chat.catflux.hu/shop-api';

const List<String> kChatFluxShopSlots = <String>[
  'decoration',
  'nameplate',
  'effect',
  'frame',
];

bool chatFluxIsHungarian(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'hu';

/// Small two-language helper, so the shop needs no entries in the l10n files.
String chatFluxTr(BuildContext context, String hu, String en) =>
    chatFluxIsHungarian(context) ? hu : en;

String chatFluxLocalize(BuildContext context, Object? text) {
  if (text == null) {
    return '';
  }
  if (text is String) {
    return text;
  }
  if (text is Map) {
    final bool hu = chatFluxIsHungarian(context);
    final Object? value = hu
        ? (text['hu'] ?? text['en'])
        : (text['en'] ?? text['hu']);
    return value?.toString() ?? '';
  }
  return text.toString();
}

/// Mobile shows the PNG renders of the artwork (the SVGs use CSS animations).
String? chatFluxAssetUrl(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  final String png = path.endsWith('.svg')
      ? '${path.substring(0, path.length - 4)}.png'
      : path;
  if (png.startsWith('http://') || png.startsWith('https://')) {
    return png;
  }
  return '$kChatFluxShopBase/${png.replaceFirst(RegExp('^/+'), '')}';
}

@immutable
class ChatFluxRender {
  const ChatFluxRender({
    this.sku,
    this.asset,
    this.top,
    this.bottom,
    this.color,
    this.align,
  });

  factory ChatFluxRender.fromJson(Map<dynamic, dynamic> json, {String? sku}) =>
      ChatFluxRender(
        sku: (json['sku'] as String?) ?? sku,
        asset: json['asset'] as String?,
        top: json['top'] as String?,
        bottom: json['bottom'] as String?,
        color: json['color'] as String?,
        align: json['align'] as String?,
      );

  final String? sku;
  final String? asset;
  final String? top;
  final String? bottom;
  final String? color;
  final String? align;

  Color? get parsedColor {
    final String? hex = color;
    if (hex == null || !hex.startsWith('#') || hex.length != 7) {
      return null;
    }
    final int? value = int.tryParse(hex.substring(1), radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

@immutable
class ChatFluxWorn {
  const ChatFluxWorn(this.slots);

  factory ChatFluxWorn.fromJson(Object? json) {
    final Map<String, ChatFluxRender> slots = <String, ChatFluxRender>{};
    if (json is Map) {
      for (final String slot in kChatFluxShopSlots) {
        final Object? raw = json[slot];
        if (raw is Map) {
          slots[slot] = ChatFluxRender.fromJson(raw);
        }
      }
    }
    return ChatFluxWorn(slots);
  }

  static const ChatFluxWorn empty = ChatFluxWorn(<String, ChatFluxRender>{});

  final Map<String, ChatFluxRender> slots;

  ChatFluxRender? get decoration => slots['decoration'];
  ChatFluxRender? get nameplate => slots['nameplate'];
  ChatFluxRender? get effect => slots['effect'];
  ChatFluxRender? get frame => slots['frame'];

  String get signature => slots.entries
      .map((MapEntry<String, ChatFluxRender> e) => '${e.key}:${e.value.sku}')
      .join('|');
}

@immutable
class ChatFluxItem {
  const ChatFluxItem({
    required this.sku,
    required this.type,
    required this.name,
    required this.price,
    this.collection,
    this.description,
    this.badge,
    this.featured = false,
    this.hidden = false,
    this.contains = const <String>[],
    this.render = const ChatFluxRender(),
  });

  factory ChatFluxItem.fromJson(Map<dynamic, dynamic> json) {
    final String sku = json['sku'] as String;
    return ChatFluxItem(
      sku: sku,
      type: json['type'] as String,
      name: json['name'],
      price: (json['price'] as num?)?.toInt() ?? 0,
      collection: json['collection'] as String?,
      description: json['description'],
      badge: json['badge'],
      featured: json['featured'] == true,
      hidden: json['hidden'] == true,
      contains: ((json['contains'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      render: json['render'] is Map
          ? ChatFluxRender.fromJson(json['render'] as Map, sku: sku)
          : ChatFluxRender(sku: sku),
    );
  }

  final String sku;
  final String type;
  final Object? name;
  final int price;
  final String? collection;
  final Object? description;
  final Object? badge;
  final bool featured;
  final bool hidden;
  final List<String> contains;
  final ChatFluxRender render;

  bool get isBundle => type == 'bundle';
}

@immutable
class ChatFluxCollection {
  const ChatFluxCollection({
    required this.id,
    required this.name,
    this.tagline,
    this.description,
    this.banner,
    this.accent,
    this.featured = false,
  });

  factory ChatFluxCollection.fromJson(Map<dynamic, dynamic> json) =>
      ChatFluxCollection(
        id: json['id'] as String,
        name: json['name'],
        tagline: json['tagline'],
        description: json['description'],
        banner: json['banner'] as String?,
        accent: json['accent'] as String?,
        featured: json['featured'] == true,
      );

  final String id;
  final Object? name;
  final Object? tagline;
  final Object? description;
  final String? banner;
  final String? accent;
  final bool featured;
}

@immutable
class ChatFluxCatalog {
  const ChatFluxCatalog({required this.collections, required this.items});

  factory ChatFluxCatalog.fromJson(Map<dynamic, dynamic> json) =>
      ChatFluxCatalog(
        collections:
            ((json['collections'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<dynamic, dynamic>>()
                .map(ChatFluxCollection.fromJson)
                .toList(),
        items: ((json['items'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map(ChatFluxItem.fromJson)
            .where((ChatFluxItem item) => !item.hidden)
            .toList(),
      );

  final List<ChatFluxCollection> collections;
  final List<ChatFluxItem> items;

  ChatFluxItem? item(String sku) {
    for (final ChatFluxItem item in items) {
      if (item.sku == sku) {
        return item;
      }
    }
    return null;
  }
}

/// A gift someone sent (or coins / items the admins granted).
@immutable
class ChatFluxGift {
  const ChatFluxGift({this.sku, this.coins, this.fromName});

  factory ChatFluxGift.fromJson(Map<dynamic, dynamic> json) => ChatFluxGift(
    sku: json['sku'] as String?,
    coins: (json['coins'] as num?)?.toInt(),
    fromName: json['fromName'] as String?,
  );

  final String? sku;
  final int? coins;
  final String? fromName;
}

@immutable
class ChatFluxMe {
  const ChatFluxMe({
    required this.userId,
    required this.balance,
    required this.owned,
    required this.equipped,
    required this.wearing,
    this.gifts = const <ChatFluxGift>[],
  });

  factory ChatFluxMe.fromJson(Map<dynamic, dynamic> json) => ChatFluxMe(
    userId: json['userId'].toString(),
    balance: (json['balance'] as num?)?.toInt() ?? 0,
    owned: ((json['owned'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<String>()
        .toSet(),
    equipped: <String, String>{
      if (json['equipped'] is Map)
        for (final MapEntry<dynamic, dynamic> e
            in (json['equipped'] as Map).entries)
          if (e.value is String) e.key.toString(): e.value as String,
    },
    wearing: ChatFluxWorn.fromJson(json['wearing']),
    gifts: ((json['gifts'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(ChatFluxGift.fromJson)
        .toList(),
  );

  final String userId;
  final int balance;
  final Set<String> owned;
  final Map<String, String> equipped;
  final ChatFluxWorn wearing;

  /// Unseen gifts.
  final List<ChatFluxGift> gifts;
}

class ChatFluxShopException implements Exception {
  const ChatFluxShopException(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'ChatFluxShopException($status, $code)';
}

/// Global shop state. Widgets listen to the ValueNotifiers.
class ChatFluxShopStore {
  ChatFluxShopStore._();

  static final ChatFluxShopStore instance = ChatFluxShopStore._();

  static const Duration _wornTtl = Duration(minutes: 3);
  static const Duration _batchDelay = Duration(milliseconds: 80);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: kChatFluxShopBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  final ValueNotifier<ChatFluxCatalog?> catalog =
      ValueNotifier<ChatFluxCatalog?>(null);
  final ValueNotifier<ChatFluxMe?> me = ValueNotifier<ChatFluxMe?>(null);
  final ValueNotifier<String?> pendingSku = ValueNotifier<String?>(null);

  final Map<String, ValueNotifier<ChatFluxWorn>> _worn =
      <String, ValueNotifier<ChatFluxWorn>>{};
  final Map<String, DateTime> _fetchedAt = <String, DateTime>{};
  final Set<String> _queue = <String>{};
  Timer? _timer;

  /// What a user wears. Unknown users are fetched in batches.
  ValueNotifier<ChatFluxWorn> worn(String userId) {
    final ValueNotifier<ChatFluxWorn> notifier = _worn.putIfAbsent(
      userId,
      () => ValueNotifier<ChatFluxWorn>(ChatFluxWorn.empty),
    );
    final DateTime? fetched = _fetchedAt[userId];
    if (fetched == null || DateTime.now().difference(fetched) > _wornTtl) {
      _enqueue(userId);
    }
    return notifier;
  }

  bool owns(ChatFluxItem item) {
    final Set<String> owned = me.value?.owned ?? const <String>{};
    if (item.isBundle) {
      return item.contains.every(owned.contains);
    }
    return owned.contains(item.sku);
  }

  bool isEquipped(ChatFluxItem item) =>
      !item.isBundle && me.value?.equipped[item.type] == item.sku;

  int piecesPrice(ChatFluxItem item) => item.contains.fold<int>(
    0,
    (int sum, String sku) => sum + (catalog.value?.item(sku)?.price ?? 0),
  );

  int priceFor(ChatFluxItem item) {
    final ChatFluxMe? current = me.value;
    if (!item.isBundle || current == null) {
      return item.price;
    }
    final int missing = item.contains
        .where((String sku) => !current.owned.contains(sku))
        .fold<int>(
          0,
          (int sum, String sku) => sum + (catalog.value?.item(sku)?.price ?? 0),
        );
    return missing < item.price ? missing : item.price;
  }

  Future<void> loadCatalog() async {
    final Response<dynamic> res = await _dio.get<dynamic>('/catalog');
    final Object? data = res.data;
    if (data is! Map) {
      throw const ChatFluxShopException(0, 'bad_response');
    }
    catalog.value = ChatFluxCatalog.fromJson(data);
  }

  Future<void> loadMe(String token) async {
    _apply(await _authed('GET', '/me', token));
  }

  Future<void> purchase(String token, String sku) => _pending(
    sku,
    () async => _apply(
      await _authed('POST', '/purchase', token, <String, Object?>{'sku': sku}),
    ),
  );

  Future<void> equip(String token, String slot, String? sku) => _pending(
    sku ?? 'unequip:$slot',
    () async => _apply(
      await _authed('POST', '/equip', token, <String, Object?>{
        'slot': slot,
        'sku': sku,
      }),
    ),
  );

  /// Buys [sku] for [toUserId]. Returns the recipient's name, if known.
  Future<String?> gift(String token, String sku, String toUserId) async {
    String? name;
    await _pending('gift:$sku', () async {
      final Map<dynamic, dynamic> json = await _authed(
        'POST',
        '/gift',
        token,
        <String, Object?>{'sku': sku, 'toUserId': toUserId},
      );
      _apply(json);
      final Object? to = json['giftedTo'];
      if (to is Map && to['name'] is String) {
        name = to['name'] as String;
      }
    });
    _fetchedAt.remove(toUserId);
    return name;
  }

  Future<void> markGiftsSeen(String token) async {
    _apply(await _authed('POST', '/gifts/seen', token));
  }

  Future<void> _pending(String key, Future<void> Function() run) async {
    pendingSku.value = key;
    try {
      await run();
    } finally {
      pendingSku.value = null;
    }
  }

  Future<Map<dynamic, dynamic>> _authed(
    String method,
    String path,
    String token, [
    Map<String, Object?>? body,
  ]) async {
    try {
      final Response<dynamic> res = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: <String, String>{'Authorization': token},
          contentType: body == null ? null : Headers.jsonContentType,
        ),
      );
      final Object? data = res.data;
      if (data is! Map) {
        throw const ChatFluxShopException(0, 'bad_response');
      }
      return data;
    } on DioException catch (error) {
      final Object? data = error.response?.data;
      final String code = data is Map && data['error'] is String
          ? data['error'] as String
          : 'network';
      throw ChatFluxShopException(error.response?.statusCode ?? 0, code);
    }
  }

  void _apply(Map<dynamic, dynamic> json) {
    final ChatFluxMe next = ChatFluxMe.fromJson(json);
    me.value = next;
    _fetchedAt[next.userId] = DateTime.now();
    _worn
            .putIfAbsent(
              next.userId,
              () => ValueNotifier<ChatFluxWorn>(ChatFluxWorn.empty),
            )
            .value =
        next.wearing;
  }

  void _enqueue(String userId) {
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      return;
    }
    _fetchedAt[userId] = DateTime.now();
    _queue.add(userId);
    _timer ??= Timer(_batchDelay, _flush);
  }

  void _flush() {
    _timer = null;
    final List<String> ids = _queue.toList();
    _queue.clear();
    for (int i = 0; i < ids.length; i += 100) {
      final List<String> batch = ids.sublist(
        i,
        i + 100 > ids.length ? ids.length : i + 100,
      );
      unawaited(_fetchBatch(batch));
    }
  }

  Future<void> _fetchBatch(List<String> batch) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/cosmetics',
        queryParameters: <String, String>{'ids': batch.join(',')},
      );
      final Object? users = res.data is Map ? (res.data as Map)['users'] : null;
      if (users is! Map) {
        return;
      }
      for (final String id in batch) {
        final ChatFluxWorn next = ChatFluxWorn.fromJson(users[id]);
        final ValueNotifier<ChatFluxWorn>? notifier = _worn[id];
        if (notifier != null && notifier.value.signature != next.signature) {
          notifier.value = next;
        }
      }
    } on Object catch (error) {
      debugPrint('[ChatFluxShop] cosmetics failed: $error');
    }
  }
}
