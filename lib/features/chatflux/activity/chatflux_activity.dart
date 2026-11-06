// ChatFlux game activity: which game someone plays, as reported by the ChatFlux desktop app
// to the activity service next to the server (https://chat.catflux.hu/shop-api).
// Same data as the web app: GET /activities for the current game, and the
// /activity/events stream (server-sent events) that says whose game just changed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Duration _kPoll = Duration(seconds: 30);
const Duration _kPollWhileLive = Duration(minutes: 5);
const Duration _kBatchDelay = Duration(milliseconds: 80);
const Duration _kEventsRetry = Duration(seconds: 3);
const int _kBatchSize = 100;

@immutable
class ChatFluxGameActivity {
  const ChatFluxGameActivity({
    required this.id,
    required this.name,
    required this.startedAt,
    this.icon,
  });

  factory ChatFluxGameActivity.fromJson(Map<dynamic, dynamic> json) =>
      ChatFluxGameActivity(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
        icon: json['icon'] as String?,
      );

  final String id;
  final String name;
  final int startedAt;
  final String? icon;

  String? get iconUrl {
    final String? path = icon;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$kChatFluxShopBase/${path.replaceFirst(RegExp('^/+'), '')}';
  }

  @override
  bool operator ==(Object other) =>
      other is ChatFluxGameActivity &&
      other.id == id &&
      other.name == name &&
      other.startedAt == startedAt &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, startedAt, icon);
}

/// Activity is fetched per server, because people choose where they share it.
String _keyOf(String userId, String? guildId) => '${guildId ?? ''}|$userId';

class ChatFluxActivityStore extends ChangeNotifier {
  ChatFluxActivityStore._();

  static final ChatFluxActivityStore instance = ChatFluxActivityStore._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: kChatFluxShopBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final Map<String, ChatFluxGameActivity> _activities =
      <String, ChatFluxGameActivity>{};
  final Map<String, int> _watchers = <String, int>{};
  final Map<String, DateTime> _fetchedAt = <String, DateTime>{};
  final Set<String> _queue = <String>{};
  Timer? _batchTimer;
  Timer? _poller;
  DateTime _lastPoll = DateTime.fromMillisecondsSinceEpoch(0);
  HttpClient? _eventsClient;
  bool _eventsWanted = false;
  bool _eventsOpen = false;

  ChatFluxGameActivity? get(String userId, String? guildId) =>
      _activities[_keyOf(userId, guildId)];

  /// Keeps the activity of [userId] fresh while something on screen shows it.
  /// Returns the unwatch function.
  VoidCallback watch(String userId, String? guildId) {
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      return () {};
    }
    final String key = _keyOf(userId, guildId);
    _watchers[key] = (_watchers[key] ?? 0) + 1;
    final DateTime? fetched = _fetchedAt[key];
    if (fetched == null ||
        (!_eventsOpen && DateTime.now().difference(fetched) > _kPoll)) {
      _enqueue(key);
    }
    _connectEvents();
    _poller ??= Timer.periodic(_kPoll, (_) => _poll());
    var done = false;
    return () {
      if (done) {
        return;
      }
      done = true;
      final int count = (_watchers[key] ?? 1) - 1;
      if (count > 0) {
        _watchers[key] = count;
        return;
      }
      _watchers.remove(key);
      // Nobody gets change events for it any more, so fetch it again next time.
      _fetchedAt.remove(key);
      if (_watchers.isEmpty) {
        _poller?.cancel();
        _poller = null;
        _disconnectEvents();
      }
    };
  }

  void refreshUser(String userId) {
    for (final String key in _watchers.keys) {
      if (key.endsWith('|$userId')) {
        _enqueue(key);
      }
    }
  }

  void _poll() {
    if (_eventsOpen && DateTime.now().difference(_lastPoll) < _kPollWhileLive) {
      return;
    }
    _lastPoll = DateTime.now();
    _watchers.keys.forEach(_enqueue);
  }

  void _enqueue(String key) {
    _fetchedAt[key] = DateTime.now();
    _queue.add(key);
    _batchTimer ??= Timer(_kBatchDelay, _flush);
  }

  void _flush() {
    _batchTimer = null;
    final Map<String, List<String>> byGuild = <String, List<String>>{};
    for (final String key in _queue) {
      final int bar = key.indexOf('|');
      byGuild
          .putIfAbsent(key.substring(0, bar), () => <String>[])
          .add(key.substring(bar + 1));
    }
    _queue.clear();
    byGuild.forEach((String guild, List<String> ids) {
      for (var i = 0; i < ids.length; i += _kBatchSize) {
        final List<String> batch = ids.sublist(
          i,
          i + _kBatchSize > ids.length ? ids.length : i + _kBatchSize,
        );
        unawaited(_fetch(guild, batch));
      }
    });
  }

  Future<void> _fetch(String guild, List<String> ids) async {
    try {
      final Response<dynamic> res = await _dio.get<dynamic>(
        '/activities',
        queryParameters: <String, String>{
          'ids': ids.join(','),
          if (guild.isNotEmpty) 'guild': guild,
        },
      );
      final Map<dynamic, dynamic> users =
          ((res.data as Map<dynamic, dynamic>?)?['users']
              as Map<dynamic, dynamic>?) ??
          const <dynamic, dynamic>{};
      var changed = false;
      for (final String id in ids) {
        final String key = _keyOf(id, guild.isEmpty ? null : guild);
        final Object? raw = users[id];
        if (raw is! Map) {
          changed |= _activities.remove(key) != null;
          continue;
        }
        final ChatFluxGameActivity next = ChatFluxGameActivity.fromJson(raw);
        if (_activities[key] != next) {
          _activities[key] = next;
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
      }
    } on Object {
      // The activity service is optional; the next poll tries again.
    }
  }

  /// Listens for "someone's game changed" pushes.
  void _connectEvents() {
    if (_eventsWanted) {
      return;
    }
    _eventsWanted = true;
    unawaited(_eventsLoop());
  }

  void _disconnectEvents() {
    _eventsWanted = false;
    _eventsOpen = false;
    _eventsClient?.close(force: true);
    _eventsClient = null;
  }

  Future<void> _eventsLoop() async {
    while (_eventsWanted) {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 60);
      _eventsClient = client;
      try {
        final HttpClientRequest req = await client.getUrl(
          Uri.parse('$kChatFluxShopBase/activity/events'),
        );
        req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        final HttpClientResponse res = await req.close();
        if (res.statusCode == 200) {
          // We may have missed changes while disconnected.
          if (!_eventsOpen) {
            _watchers.keys.forEach(_enqueue);
          }
          _eventsOpen = true;
          var event = 'message';
          final StringBuffer data = StringBuffer();
          // The service pings every 20 s; a silent minute means the link is dead.
          await for (final String line
              in res
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .timeout(const Duration(seconds: 60))) {
            if (!_eventsWanted) {
              break;
            }
            if (line.isEmpty) {
              if (event == 'change') {
                _handleChange(data.toString());
              }
              event = 'message';
              data.clear();
            } else if (line.startsWith('event:')) {
              event = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              data.write(line.substring(5).trim());
            }
          }
        }
      } on Object {
        // Network error or service down; retry below.
      } finally {
        _eventsOpen = false;
        client.close(force: true);
        if (identical(_eventsClient, client)) {
          _eventsClient = null;
        }
      }
      if (_eventsWanted) {
        await Future<void>.delayed(_kEventsRetry);
      }
    }
  }

  void _handleChange(String raw) {
    try {
      final Object? json = jsonDecode(raw);
      final Object? id = json is Map ? json['id'] : null;
      if (id is String && id.isNotEmpty) {
        refreshUser(id);
      }
    } on Object {
      // Ignore malformed events.
    }
  }
}

/// Rebuilds [builder] with the game [userId] plays (null when none or hidden).
class ChatFluxGameActivityBuilder extends StatefulWidget {
  const ChatFluxGameActivityBuilder({
    required this.userId,
    required this.builder,
    this.guildId,
    super.key,
  });

  final String? userId;
  final String? guildId;
  final Widget Function(BuildContext context, ChatFluxGameActivity? activity)
  builder;

  @override
  State<ChatFluxGameActivityBuilder> createState() =>
      _ChatFluxGameActivityBuilderState();
}

class _ChatFluxGameActivityBuilderState
    extends State<ChatFluxGameActivityBuilder> {
  VoidCallback? _unwatch;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ChatFluxGameActivityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.guildId != widget.guildId) {
      _unwatch?.call();
      _subscribe();
    }
  }

  void _subscribe() {
    final String? userId = widget.userId;
    _unwatch = userId == null
        ? null
        : ChatFluxActivityStore.instance.watch(userId, widget.guildId);
  }

  @override
  void dispose() {
    _unwatch?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ChatFluxActivityStore.instance,
    builder: (BuildContext context, _) {
      final String? userId = widget.userId;
      return widget.builder(
        context,
        userId == null
            ? null
            : ChatFluxActivityStore.instance.get(userId, widget.guildId),
      );
    },
  );
}

class ChatFluxGameIcon extends StatelessWidget {
  const ChatFluxGameIcon({required this.activity, required this.size, super.key});

  final ChatFluxGameActivity activity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? url = activity.iconUrl;
    final Widget fallback = PhosphorIcon(
      PhosphorIconsFill.gameController,
      size: size * 0.8,
      color: context.colors.textPrimaryMuted,
    );
    return SizedBox(
      width: size,
      height: size,
      child: url == null
          ? Center(child: fallback)
          : ClipRRect(
              borderRadius: BorderRadius.circular(size / 5),
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: fallback),
              ),
            ),
    );
  }
}

/// One line under a name: icon + "Játszik: Game". Shows [fallback] when not playing.
class ChatFluxGameActivityLine extends StatelessWidget {
  const ChatFluxGameActivityLine({
    required this.userId,
    this.guildId,
    this.style,
    this.fallback,
    super.key,
  });

  final String? userId;
  final String? guildId;
  final TextStyle? style;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => ChatFluxGameActivityBuilder(
    userId: userId,
    guildId: guildId,
    builder: (BuildContext context, ChatFluxGameActivity? activity) {
      if (activity == null) {
        return fallback ?? const SizedBox.shrink();
      }
      final TextStyle textStyle =
          style ??
          context.textStyles.timestamp.copyWith(
            color: context.colors.textPrimaryMuted,
            fontSize: 12,
          );
      final double iconSize = (textStyle.fontSize ?? 12) + 2;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ChatFluxGameIcon(activity: activity, size: iconSize),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              chatFluxTr(
                context,
                'Játszik: ${activity.name}',
                'Playing ${activity.name}',
              ),
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    },
  );
}

/// 49:36 or 1:02:05
String chatFluxFormatElapsed(Duration elapsed) {
  final int total = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final int hours = total ~/ 3600;
  final int minutes = (total % 3600) ~/ 60;
  final int seconds = total % 60;
  String pad(int n) => n.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${pad(minutes)}:${pad(seconds)}'
      : '${pad(minutes)}:${pad(seconds)}';
}

/// Profile card: "Most játszik" with the game icon, name and play time.
class ChatFluxGameActivityCard extends StatelessWidget {
  const ChatFluxGameActivityCard({
    required this.userId,
    this.guildId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String? userId;
  final String? guildId;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ChatFluxGameActivityBuilder(
    userId: userId,
    guildId: guildId,
    builder: (BuildContext context, ChatFluxGameActivity? activity) {
      if (activity == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: padding,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.backgroundModifierAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              ChatFluxGameIcon(activity: activity, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      chatFluxTr(context, 'MOST JÁTSZIK', 'PLAYING NOW'),
                      style: context.textStyles.timestamp.copyWith(
                        color: context.colors.textPrimaryMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.name,
                      style: context.textStyles.username.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (activity.startedAt > 0)
                      _ElapsedText(
                        startedAt: activity.startedAt,
                        style: context.textStyles.timestamp.copyWith(
                          color: context.colors.textPrimaryMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

@immutable
class ChatFluxRecentGame {
  const ChatFluxRecentGame({
    required this.activity,
    required this.lastPlayed,
    required this.playing,
  });

  final ChatFluxGameActivity activity;
  final int lastPlayed;
  final bool playing;
}

Future<List<ChatFluxRecentGame>> chatFluxFetchRecentGames(
  String userId,
  String? guildId,
) async {
  final Response<dynamic> res = await ChatFluxActivityStore.instance._dio
      .get<dynamic>(
        '/activity/recent',
        queryParameters: <String, String>{
          'id': userId,
          if (guildId != null) 'guild': guildId,
        },
      );
  final List<dynamic> list =
      ((res.data as Map<dynamic, dynamic>?)?['recent'] as List<dynamic>?) ??
      const <dynamic>[];
  return <ChatFluxRecentGame>[
    for (final Object? raw in list)
      if (raw is Map)
        ChatFluxRecentGame(
          activity: ChatFluxGameActivity.fromJson(raw),
          lastPlayed: (raw['lastPlayed'] as num?)?.toInt() ?? 0,
          playing: raw['playing'] == true,
        ),
  ];
}

/// "5 perce", "3 napja" / "5m ago", "3d ago"
String chatFluxFormatAgo(BuildContext context, int timestamp) {
  final int minutes =
      DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
          .inMinutes;
  if (minutes < 1) {
    return chatFluxTr(context, 'épp most', 'just now');
  }
  if (minutes < 60) {
    return chatFluxTr(context, '$minutes perce', '${minutes}m ago');
  }
  final int hours = minutes ~/ 60;
  if (hours < 24) {
    return chatFluxTr(context, '$hours órája', '${hours}h ago');
  }
  final int days = hours ~/ 24;
  return chatFluxTr(context, '$days napja', '${days}d ago');
}

/// Profile section: games played in the last 30 days.
class ChatFluxRecentGames extends StatefulWidget {
  const ChatFluxRecentGames({
    required this.userId,
    this.guildId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String? userId;
  final String? guildId;
  final EdgeInsetsGeometry padding;

  @override
  State<ChatFluxRecentGames> createState() => _ChatFluxRecentGamesState();
}

class _ChatFluxRecentGamesState extends State<ChatFluxRecentGames> {
  List<ChatFluxRecentGame> _recent = const <ChatFluxRecentGame>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ChatFluxRecentGames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.guildId != widget.guildId) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final String? userId = widget.userId;
    if (userId == null || !RegExp(r'^\d+$').hasMatch(userId)) {
      if (mounted) {
        setState(() => _recent = const <ChatFluxRecentGame>[]);
      }
      return;
    }
    try {
      final List<ChatFluxRecentGame> recent = await chatFluxFetchRecentGames(
        userId,
        widget.guildId,
      );
      if (mounted && widget.userId == userId) {
        setState(() => _recent = recent);
      }
    } on Object {
      // The activity service is optional.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recent.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextStyle mutedStyle = context.textStyles.timestamp.copyWith(
      color: context.colors.textPrimaryMuted,
      fontSize: 12,
    );
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            chatFluxTr(context, 'NEMRÉG JÁTSZOTT', 'RECENTLY PLAYED'),
            style: mutedStyle.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          for (final ChatFluxRecentGame game in _recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  ChatFluxGameIcon(activity: game.activity, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          game.activity.name,
                          style: context.textStyles.username.copyWith(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          game.playing
                              ? chatFluxTr(context, 'Most játszik', 'Playing now')
                              : chatFluxFormatAgo(context, game.lastPlayed),
                          style: game.playing
                              ? mutedStyle.copyWith(
                                  color: context.colors.statusOnline,
                                )
                              : mutedStyle,
                        ),
                      ],
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

class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.startedAt, required this.style});

  final int startedAt;
  final TextStyle style;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(widget.startedAt),
    );
    return Text(
      chatFluxTr(
        context,
        '${chatFluxFormatElapsed(elapsed)} óta',
        'for ${chatFluxFormatElapsed(elapsed)}',
      ),
      style: widget.style,
    );
  }
}
