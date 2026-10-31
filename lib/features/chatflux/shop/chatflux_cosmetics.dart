// ChatFlux Shop: draws bought cosmetics (avatar decoration, nameplate,
// profile effect, profile frame) on top of the normal UI.

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';

/// Smallest avatar that still gets its decoration.
const double kChatFluxMinDecoratedAvatar = 24;

Widget _shopImage(
  String url, {
  BoxFit fit = BoxFit.contain,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
}) => CachedNetworkImage(
  imageUrl: url,
  fit: fit,
  alignment: alignment,
  width: width,
  height: height,
  fadeInDuration: Duration.zero,
  fadeOutDuration: Duration.zero,
  placeholder: (_, _) => const SizedBox.shrink(),
  errorBuilder: (_, _, _) => const SizedBox.shrink(),
);

/// Decoration image only (120% of the avatar, centred), for previews.
class ChatFluxDecorationOverlay extends StatelessWidget {
  const ChatFluxDecorationOverlay({
    required this.render,
    required this.size,
    required this.child,
    super.key,
  });

  final ChatFluxRender? render;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String? url = chatFluxAssetUrl(render?.asset);
    if (url == null) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          left: -size * 0.1,
          top: -size * 0.1,
          width: size * 1.2,
          height: size * 1.2,
          child: IgnorePointer(child: _shopImage(url)),
        ),
      ],
    );
  }
}

/// Wraps a user's avatar and draws their worn decoration around it.
class ChatFluxAvatarDecoration extends StatelessWidget {
  const ChatFluxAvatarDecoration({
    required this.userId,
    required this.size,
    required this.child,
    super.key,
  });

  final String userId;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (size < kChatFluxMinDecoratedAvatar) {
      return child;
    }
    return ValueListenableBuilder<ChatFluxWorn>(
      valueListenable: ChatFluxShopStore.instance.worn(userId),
      child: child,
      builder: (BuildContext context, ChatFluxWorn worn, Widget? child) =>
          ChatFluxDecorationOverlay(
            render: worn.decoration,
            size: size,
            child: child!,
          ),
    );
  }
}

/// Nameplate background (use inside Positioned.fill behind a row).
class ChatFluxNameplateBackground extends StatelessWidget {
  const ChatFluxNameplateBackground({
    required this.render,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    super.key,
  });

  final ChatFluxRender? render;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final String? url = chatFluxAssetUrl(render?.asset);
    if (url == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Opacity(
          opacity: 0.9,
          child: _shopImage(
            url,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

/// Nameplate of a user, looked up from the shop store.
class ChatFluxUserNameplate extends StatelessWidget {
  const ChatFluxUserNameplate({
    required this.userId,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    super.key,
  });

  final String userId;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ChatFluxWorn>(
    valueListenable: ChatFluxShopStore.instance.worn(userId),
    builder: (BuildContext context, ChatFluxWorn worn, Widget? _) =>
        ChatFluxNameplateBackground(
          render: worn.nameplate,
          borderRadius: borderRadius,
        ),
  );
}

/// Profile effect image covering its box.
class ChatFluxEffectLayer extends StatelessWidget {
  const ChatFluxEffectLayer({required this.render, super.key});

  final ChatFluxRender? render;

  @override
  Widget build(BuildContext context) {
    final String? url = chatFluxAssetUrl(render?.asset);
    if (url == null) {
      return const SizedBox.shrink();
    }
    final Alignment alignment = switch (render?.align) {
      'bottom' => Alignment.bottomCenter,
      'center' => Alignment.center,
      _ => Alignment.topCenter,
    };
    return IgnorePointer(
      child: _shopImage(url, fit: BoxFit.cover, alignment: alignment),
    );
  }
}

/// Top piece of a frame. Its art is 340x110 with the card edge at y=40,
/// so only the part from the card edge down is shown here.
class ChatFluxFrameTop extends StatelessWidget {
  const ChatFluxFrameTop({required this.render, super.key});

  final ChatFluxRender? render;

  @override
  Widget build(BuildContext context) {
    final String? url = chatFluxAssetUrl(render?.top);
    if (url == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 70 / 110,
          child: AspectRatio(
            aspectRatio: 340 / 110,
            child: _shopImage(url, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}

/// Effect + frame for a user's profile header area.
class ChatFluxProfileHeaderCosmetics extends StatelessWidget {
  const ChatFluxProfileHeaderCosmetics({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ChatFluxWorn>(
    valueListenable: ChatFluxShopStore.instance.worn(userId),
    builder: (BuildContext context, ChatFluxWorn worn, Widget? _) {
      if (worn.effect == null && worn.frame == null) {
        return const SizedBox.shrink();
      }
      return Stack(
        children: <Widget>[
          if (worn.effect != null)
            Positioned.fill(child: ChatFluxEffectLayer(render: worn.effect)),
          if (worn.frame != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChatFluxFrameTop(render: worn.frame),
            ),
        ],
      );
    },
  );
}
