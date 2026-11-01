// ChatFlux: on Android 14+ an app needs the "full screen notifications"
// permission to show the incoming-call screen over the lock screen. Without it
// a call only vibrates. Ask for it with a clear explanation.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:fluxer_app/core/router/shell_navigator_keys.dart';
import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart'
    show chatFluxTr;
import 'package:fluxer_app/features/ui/button/fluxer_button.dart';
import 'package:fluxer_app/features/ui/modal/fluxer_modal.dart';
import 'package:fluxer_app/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatFluxCallPermission {
  ChatFluxCallPermission._();

  static const String _lastAskedKey = 'chatflux.fsi_last_asked_ms';
  static const Duration _askEvery = Duration(days: 2);
  static const Duration _firstDelay = Duration(seconds: 4);

  static void start() {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    Timer(_firstDelay, () => unawaited(_check()));
  }

  static Future<void> _check() async {
    try {
      if (await FlutterCallkitIncoming.canUseFullScreenIntent()) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int last = prefs.getInt(_lastAskedKey) ?? 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _askEvery.inMilliseconds) {
        return;
      }
      final BuildContext? context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      await prefs.setInt(_lastAskedKey, now);
      if (!context.mounted) {
        return;
      }
      final bool? accepted = await FluxerModal.show<bool>(
        context,
        title: chatFluxTr(
          context,
          'Hívások zárolt képernyőn',
          'Calls on the lock screen',
        ),
        centered: true,
        useRootNavigator: true,
        builder: (BuildContext dialogContext, VoidCallback close) => Text(
          chatFluxTr(
            dialogContext,
            'Ahhoz, hogy egy bejövő hívásnál a hívás képernyő zárolt telefonon '
                'is megjelenjen (és ne csak rezegjen), engedélyezd a ChatFluxnak '
                'a teljes képernyős értesítéseket.\n\n'
                'A következő képernyőn kapcsold be, majd lépj vissza.',
            'To show the incoming call screen while your phone is locked '
                '(instead of only vibrating), allow ChatFlux to use full screen '
                'notifications.\n\nTurn it on on the next screen, then come back.',
          ),
          style: dialogContext.textStyles.bodySmall.copyWith(height: 1.4),
        ),
        actionsBuilder: (void Function([bool? result]) pop) => [
          FluxerButton.secondary(
            onPressed: () => pop(false),
            label: chatFluxTr(context, 'Később', 'Later'),
          ),
          FluxerButton.primary(
            onPressed: () => pop(true),
            label: chatFluxTr(context, 'Beállítás', 'Open settings'),
          ),
        ],
      );
      if (accepted ?? false) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } on Object catch (error) {
      debugPrint('[ChatFluxCallPermission] check failed: $error');
    }
  }
}
