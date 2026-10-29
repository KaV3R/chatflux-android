import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/features/guilds/presentation/widgets/guild_drag_wrapper.dart';
import 'package:fluxer_app/features/guilds/presentation/widgets/guild_icon_peek_gesture_host.dart';
import 'package:fluxer_app/features/guilds/presentation/widgets/guild_icon_peek_menu.dart';
import 'package:fluxer_app/features/guilds/presentation/widgets/guild_long_press_menu_host.dart';
import 'package:fluxer_app/features/ui/action_menu/sidebar_peek_menu_panel.dart';
import 'package:fluxer_app/features/ui/bottom_sheet/fluxer_bottom_sheet.dart';
import 'package:fluxer_app/material_ui.dart';
import 'package:fluxer_app/shared/providers/input_modality_provider.dart';

import '../../../../helpers/pump_fluxer_app.dart';

class _TouchInput extends InputModalityNotifier {
  @override
  bool build() => true;
}

const Key _iconKey = Key('rail-community-icon');

class _PeekMenu extends GuildIconPeekMenuConfig {
  _PeekMenu()
    : super(guildName: 'Test', hasUnread: false, onAction: (_, _) async {});

  int opened = 0;

  @override
  Widget buildPanel({
    required BuildContext context,
    required ValueChanged<Object> onSelect,
  }) {
    opened++;
    return super.buildPanel(context: context, onSelect: onSelect);
  }
}

Future<void> _pumpRail(WidgetTester tester, _PeekMenu menu) {
  return tester.pumpWidget(
    pumpFluxerApp(
      overrides: [inputModalityProvider.overrideWith(_TouchInput.new)],
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: GuildDragWrapper(
            itemId: 'guild-1',
            isFolder: false,
            dragFeedback: const SizedBox.square(dimension: 48),
            peekMenu: menu,
            child: const SizedBox.square(
              key: _iconKey,
              dimension: 48,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('holding a community icon opens its peek menu, not a sheet', (
    tester,
  ) async {
    final _PeekMenu menu = _PeekMenu();
    await _pumpRail(tester, menu);
    await tester.pumpAndSettle();

    expect(find.byType(GuildIconPeekGestureHost), findsOneWidget);
    expect(find.byType(GuildLongPressMenuHost), findsNothing);

    final TestGesture hold = await tester.startGesture(
      tester.getCenter(find.byKey(_iconKey)),
    );
    await tester.pump(kGuildPeekHoldDelay);
    await tester.pump();
    expect(menu.opened, 1);
    expect(find.byType(SidebarPeekMenuPanel), findsOneWidget);
    expect(find.byType(FluxerMenuGroup), findsOneWidget);

    await hold.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a quick tap on a community icon does not open its peek menu', (
    tester,
  ) async {
    final _PeekMenu menu = _PeekMenu();
    await _pumpRail(tester, menu);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_iconKey));
    await tester.pumpAndSettle();

    expect(menu.opened, 0);
  });

  testWidgets('dragging a held community icon dismisses its peek menu', (
    tester,
  ) async {
    final _PeekMenu menu = _PeekMenu();
    await _pumpRail(tester, menu);
    await tester.pumpAndSettle();

    final TestGesture hold = await tester.startGesture(
      tester.getCenter(find.byKey(_iconKey)),
    );
    await tester.pump(kGuildPeekHoldDelay);
    await tester.pump();
    expect(find.byType(SidebarPeekMenuPanel), findsOneWidget);
    await tester.pump(kLongPressTimeout - kGuildPeekHoldDelay);
    for (int i = 0; i < 6; i++) {
      await hold.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(SidebarPeekMenuPanel), findsNothing);
    await hold.up();
    await tester.pumpAndSettle();
  });
}
