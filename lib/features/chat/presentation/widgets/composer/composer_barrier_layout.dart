import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/features/chat/presentation/widgets/composer/mobile_composer_bar.dart';
import 'package:fluxer_app/features/chat/presentation/widgets/composer/wide_composer_layout.dart';
import 'package:fluxer_app/features/chat/providers/pickers/attachment_panel_provider.dart';
import 'package:fluxer_app/features/chat/providers/pickers/bottom_input_slot_provider.dart';
import 'package:fluxer_app/features/chat/providers/pickers/expression_panel_provider.dart';
import 'package:fluxer_app/features/chat/utils/composer/bottom_input_slot_layout.dart';
import 'package:fluxer_app/features/chat/utils/composer/composer_panel.dart';
import 'package:fluxer_app/features/shell/presentation/responsive_layout.dart';
import 'package:fluxer_app/material_ui.dart';

EdgeInsetsGeometry composerBarrierContentPadding(BuildContext context) {
  if (isMobileLayout(context)) {
    return MobileComposerLayout.rowPadding;
  }
  return const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: WideComposerLayout.densePaddingY,
  );
}

class ComposerBarrierLayout extends ConsumerWidget {
  const ComposerBarrierLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool mobileComposer = isMobileLayout(context);
    final bool isPanelOpen = isComposerPanelOpen(
      expressionPanelOpen: ref.watch(expressionPanelProvider),
      attachmentPanelOpen: ref.watch(attachmentPanelProvider),
    );
    final double bottomSlotHeight = ref.watch(
      bottomInputSlotProvider.select(
        (BottomInputSlotState state) => state.slotHeight,
      ),
    );
    final double safeAreaBottom = MediaQuery.paddingOf(context).bottom;
    final bool showComposerSafeBar = shouldShowComposerSafeAreaBar(
      safeAreaBottom: safeAreaBottom,
      bottomSlotHeight: bottomSlotHeight,
      isPanelOpen: isPanelOpen,
      keyboardInsetBottom: resolvedKeyboardInsetBottom(context),
    );
    final Widget boxChild = Padding(
      padding: composerBarrierContentPadding(context),
      child: child,
    );

    if (mobileComposer) {
      final double mobileSafeBarHeight =
          safeAreaBottom - MobileComposerLayout.bottomGap;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MobileComposerLayout.sideInset,
              MobileComposerLayout.topInset,
              MobileComposerLayout.sideInset,
              MobileComposerLayout.bottomGap,
            ),
            child: MobileComposerBar(child: boxChild),
          ),
          if (showComposerSafeBar && mobileSafeBarHeight > 0)
            SizedBox(height: mobileSafeBarHeight),
        ],
      );
    }

    final Widget? composerSafeBar = showComposerSafeBar
        ? Container(
            height: safeAreaBottom,
            decoration: BoxDecoration(
              color: context.colors.backgroundSecondaryLighter,
            ),
          )
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ColoredBox(
          color: context.colors.backgroundSecondaryLighter,
          child: Padding(
            padding: const EdgeInsets.all(WideComposerLayout.boxInset),
            child: WideComposerFloatingBox(focused: false, child: boxChild),
          ),
        ),
        ?composerSafeBar,
      ],
    );
  }
}
