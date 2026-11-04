// ChatFlux Shop: display name styles (bought font + effect, coloured by the
// user), drawn in chat, in the member list and on profiles.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';
import 'package:path_provider/path_provider.dart';

const List<String> kChatFluxDefaultNameColors = <String>['#c084fc', '#f472b6'];

/// Loads shop fonts on demand and keeps them on disk between app starts.
class ChatFluxNameFonts {
  ChatFluxNameFonts._();

  static final Map<String, Future<void>> _loads = <String, Future<void>>{};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  static String family(String font) => 'ChatFluxName-$font';

  static void ensure(String? font, String? file) {
    if (font == null || file == null || _loads.containsKey(font)) {
      return;
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(font)) {
      return;
    }
    _loads[font] = _load(font, file).catchError((Object error) {
      debugPrint('[ChatFluxShop] font $font failed: $error');
      // Allow another try later.
      unawaited(
        Future<void>.delayed(
          const Duration(minutes: 2),
          () => _loads.remove(font),
        ),
      );
    });
  }

  static Future<void> _load(String font, String file) async {
    Uint8List? bytes;
    File? cached;
    try {
      final Directory dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/chatflux_fonts',
      );
      cached = File('${dir.path}/$font.ttf');
      if (cached.existsSync()) {
        bytes = await cached.readAsBytes();
      }
    } on Object {
      cached = null;
    }
    if (bytes == null) {
      final String? url = chatFluxAssetUrl(file);
      if (url == null) {
        return;
      }
      final Response<List<int>> res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(res.data ?? const <int>[]);
      if (bytes.isEmpty) {
        throw StateError('empty font');
      }
      if (cached != null) {
        try {
          await cached.parent.create(recursive: true);
          await cached.writeAsBytes(bytes, flush: true);
        } on Object {
          // Caching is optional.
        }
      }
    }
    final FontLoader loader = FontLoader(family(font))
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// [base] with a custom foreground paint (TextStyle can't hold both a colour and one).
TextStyle _withForeground(TextStyle base, Paint paint, List<Shadow> shadows) =>
    TextStyle(
      inherit: base.inherit,
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      fontStyle: base.fontStyle,
      letterSpacing: base.letterSpacing,
      wordSpacing: base.wordSpacing,
      height: base.height,
      leadingDistribution: base.leadingDistribution,
      textBaseline: base.textBaseline,
      fontFeatures: base.fontFeatures,
      fontVariations: base.fontVariations,
      foreground: paint,
      shadows: shadows,
    );

Color _shiftHue(Color color, double degrees) {
  final HSLColor hsl = HSLColor.fromColor(color);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

/// Resolved colours of a style.
class _NamePalette {
  factory _NamePalette(List<String> chosen) {
    final List<Color> parsed = chosen
        .map(chatFluxParseHex)
        .whereType<Color>()
        .toList();
    final Color c1 = parsed.isNotEmpty
        ? parsed[0]
        : chatFluxParseHex(kChatFluxDefaultNameColors[0])!;
    final Color c2 = parsed.length > 1
        ? parsed[1]
        : parsed.length == 1
        ? _shiftHue(c1, 50)
        : chatFluxParseHex(kChatFluxDefaultNameColors[1])!;
    return _NamePalette._(c1, c2);
  }

  _NamePalette._(this.c1, this.c2)
    : c3 = _shiftHue(c1, 120),
      c4 = _shiftHue(c2, 120),
      light = _mix(c1, Colors.white, 0.6),
      dark = _mix(c1, Colors.black, 0.7),
      shine = _mix(c1, Colors.white, 0.85);

  final Color c1;
  final Color c2;
  final Color c3;
  final Color c4;
  final Color light;
  final Color dark;
  final Color shine;
}

/// [text] drawn in [nameStyle]. Layout (size, ellipsis) follows [style].
class ChatFluxNameText extends StatefulWidget {
  const ChatFluxNameText({
    required this.text,
    required this.nameStyle,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    super.key,
  });

  final String text;
  final ChatFluxNameStyle nameStyle;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  State<ChatFluxNameText> createState() => _ChatFluxNameTextState();
}

class _ChatFluxNameTextState extends State<ChatFluxNameText>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  bool get _animated =>
      widget.nameStyle.effect == 'prism' ||
      widget.nameStyle.effect == 'shimmer';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(ChatFluxNameText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_animated && !reduceMotion) {
      final Duration duration = widget.nameStyle.effect == 'prism'
          ? const Duration(seconds: 5)
          : const Duration(milliseconds: 2800);
      if (_controller == null) {
        _controller = AnimationController(vsync: this, duration: duration)
          ..repeat();
      } else if (_controller!.duration != duration) {
        _controller!
          ..duration = duration
          ..repeat();
      }
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Text _text(TextStyle style) => Text(
    widget.text,
    style: style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
    textAlign: widget.textAlign,
    softWrap: widget.maxLines != 1,
  );

  Widget _masked(TextStyle style, Shader Function(Rect bounds) shader) =>
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: shader,
        child: _text(style.copyWith(color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    final ChatFluxNameStyle ns = widget.nameStyle;
    ChatFluxNameFonts.ensure(ns.font, ns.file);
    final _NamePalette p = _NamePalette(ns.colors);
    final double fontSize = (widget.style.fontSize ?? 14) * ns.scale;
    TextStyle base = widget.style.copyWith(fontSize: fontSize);
    if (ns.font != null) {
      // Shop fonts have one weight; faux bold would smear their details.
      base = base.copyWith(
        fontFamily: ChatFluxNameFonts.family(ns.font!),
        fontWeight: FontWeight.w400,
        fontFamilyFallback: <String>[?widget.style.fontFamily],
      );
    }
    switch (ns.effect) {
      case 'gradient':
        return _masked(
          base,
          (Rect b) =>
              LinearGradient(colors: <Color>[p.c1, p.c2]).createShader(b),
        );
      case 'neon':
        return _text(
          base.copyWith(
            color: p.light,
            shadows: <Shadow>[
              Shadow(color: p.c1, blurRadius: fontSize * 0.1),
              Shadow(color: p.c1, blurRadius: fontSize * 0.3),
              Shadow(color: p.c1, blurRadius: fontSize * 0.6),
            ],
          ),
        );
      case 'toon':
        return Stack(
          children: <Widget>[
            _text(
              _withForeground(
                base,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = fontSize * 0.13
                  ..strokeJoin = StrokeJoin.round
                  ..color = p.dark,
                <Shadow>[
                  Shadow(color: p.dark, offset: Offset(0, fontSize * 0.12)),
                ],
              ),
            ),
            _text(base.copyWith(color: p.c1)),
          ],
        );
      case 'pop':
        return _text(
          base.copyWith(
            color: p.c1,
            shadows: <Shadow>[
              Shadow(
                color: p.c2,
                offset: Offset(fontSize * 0.09, fontSize * 0.09),
              ),
            ],
          ),
        );
      case 'gummy':
        return Stack(
          children: <Widget>[
            _text(
              base.copyWith(
                color: const Color(0x00000000),
                shadows: <Shadow>[
                  Shadow(color: p.dark, offset: Offset(0, fontSize * 0.08)),
                  Shadow(
                    color: p.c1.withValues(alpha: 0.6),
                    blurRadius: fontSize * 0.15,
                  ),
                ],
              ),
            ),
            _masked(
              base,
              (Rect b) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[p.light, p.c1, p.c2],
                stops: const <double>[0, 0.48, 1],
              ).createShader(b),
            ),
          ],
        );
      case 'prism':
        return _animatedMask(base, (Rect b, double t) {
          final double period = math.max(b.width, 1) * 1.5;
          return LinearGradient(
            colors: <Color>[p.c1, p.c2, p.c3, p.c4, p.c1],
            tileMode: TileMode.repeated,
          ).createShader(
            Rect.fromLTWH(b.left - t * period, b.top, period, b.height),
          );
        });
      case 'shimmer':
        return _animatedMask(base, (Rect b, double t) {
          // Sweep during the first 70 %, then rest.
          final double sweep = math.min(1, t / 0.7);
          final double w = math.max(b.width, 1);
          final double centre = b.left + w * (1.3 - 1.6 * sweep);
          return LinearGradient(
            colors: <Color>[p.c1, p.shine, p.c1],
            stops: const <double>[0.38, 0.5, 0.62],
          ).createShader(
            Rect.fromCenter(
              center: Offset(centre, b.center.dy),
              width: w * 1.2,
              height: b.height,
            ),
          );
        });
      default:
        return _text(base.copyWith(color: p.c1));
    }
  }

  Widget _animatedMask(
    TextStyle base,
    Shader Function(Rect bounds, double t) shader,
  ) {
    final AnimationController? controller = _controller;
    if (controller == null) {
      return _masked(base, (Rect b) => shader(b, 0.35));
    }
    return AnimatedBuilder(
      animation: controller,
      child: _text(base.copyWith(color: Colors.white)),
      builder: (BuildContext _, Widget? child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect b) => shader(b, controller.value),
        child: child,
      ),
    );
  }
}

/// A user's name in the style they wear (a plain [Text] when they wear none).
class ChatFluxStyledName extends StatelessWidget {
  const ChatFluxStyledName({
    required this.userId,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    super.key,
  });

  final String? userId;
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  Widget _plain() => Text(
    text,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
  );

  @override
  Widget build(BuildContext context) {
    final String? id = userId;
    if (id == null || id.isEmpty) {
      return _plain();
    }
    return ValueListenableBuilder<ChatFluxWorn>(
      valueListenable: ChatFluxShopStore.instance.worn(id),
      builder: (BuildContext context, ChatFluxWorn worn, Widget? _) {
        final ChatFluxNameStyle? ns = worn.nameStyle;
        if (ns == null) {
          return _plain();
        }
        return ChatFluxNameText(
          text: text,
          nameStyle: ns,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }
}
