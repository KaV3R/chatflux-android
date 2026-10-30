// ChatFlux: checks GitHub Releases (KaV3R/chatflux-android) for a newer Android APK,
// downloads it and opens the system installer (the user confirms with one tap).

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluxer_app/core/router/shell_navigator_keys.dart';
import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/features/ui/button/fluxer_button.dart';
import 'package:fluxer_app/features/ui/modal/fluxer_modal.dart';
import 'package:fluxer_app/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class ChatFluxAndroidUpdater {
  ChatFluxAndroidUpdater._();

  static const String _releasesUrl =
      'https://api.github.com/repos/KaV3R/chatflux-android/releases?per_page=15';
  static const String _tagPrefix = 'android-v';
  static const Duration _firstCheckDelay = Duration(seconds: 12);
  static const Duration _checkInterval = Duration(hours: 6);
  static const MethodChannel _channel = MethodChannel('chatflux/apk_installer');

  static bool _started = false;
  static bool _busy = false;
  static String? _dismissedVersion;

  static void start() {
    if (_started || kIsWeb || !Platform.isAndroid || kDebugMode) {
      return;
    }
    _started = true;
    Timer(_firstCheckDelay, () => unawaited(_check()));
    Timer.periodic(_checkInterval, (_) => unawaited(_check()));
  }

  static Future<void> _check() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final _Release? release = await _fetchLatestRelease();
      if (release == null ||
          release.version == _dismissedVersion ||
          !_isNewer(release.version, info.version)) {
        return;
      }
      final String? apkUrl = await _pickApkUrl(release);
      if (apkUrl == null) {
        return;
      }
      final BuildContext? context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      final bool? accepted = await FluxerModal.show<bool>(
        context,
        title: 'ChatFlux frissítés',
        centered: true,
        useRootNavigator: true,
        builder: (BuildContext dialogContext, VoidCallback close) => Text(
          'Új verzió érhető el: ${release.version} '
          '(most: ${info.version}).\n\n'
          'Letöltöd és telepíted most?',
          style: dialogContext.textStyles.bodySmall.copyWith(height: 1.4),
        ),
        actionsBuilder: (void Function([bool? result]) pop) => [
          FluxerButton.secondary(onPressed: () => pop(false), label: 'Később'),
          FluxerButton.primary(onPressed: () => pop(true), label: 'Frissítés'),
        ],
      );
      if (accepted != true) {
        _dismissedVersion = release.version;
        return;
      }
      await _downloadAndInstall(apkUrl, release.version);
    } on Object catch (error) {
      debugPrint('[ChatFluxUpdater] update check failed: $error');
    } finally {
      _busy = false;
    }
  }

  static Future<_Release?> _fetchLatestRelease() async {
    final Response<List<dynamic>> response = await Dio().get<List<dynamic>>(
      _releasesUrl,
      options: Options(
        headers: <String, String>{'Accept': 'application/vnd.github+json'},
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    for (final dynamic raw in response.data ?? const <dynamic>[]) {
      if (raw is! Map) {
        continue;
      }
      final Object? tag = raw['tag_name'];
      if (raw['draft'] == true ||
          raw['prerelease'] == true ||
          tag is! String ||
          !tag.startsWith(_tagPrefix)) {
        continue;
      }
      final Map<String, String> assets = <String, String>{};
      for (final dynamic asset in (raw['assets'] as List<dynamic>?) ?? []) {
        if (asset is Map &&
            asset['name'] is String &&
            asset['browser_download_url'] is String) {
          assets[asset['name'] as String] =
              asset['browser_download_url'] as String;
        }
      }
      return _Release(tag.substring(_tagPrefix.length), assets);
    }
    return null;
  }

  static Future<String?> _pickApkUrl(_Release release) async {
    List<String> abis = const <String>[];
    try {
      abis =
          (await _channel.invokeListMethod<String>('supportedAbis')) ??
          const <String>[];
    } on Object {
      // Fall back to the universal APK.
    }
    for (final String abi in abis) {
      final String? url = release.assets['ChatFlux-${release.version}-$abi.apk'];
      if (url != null) {
        return url;
      }
    }
    return release.assets['ChatFlux-${release.version}.apk'];
  }

  static Future<void> _downloadAndInstall(String url, String version) async {
    final Directory cache = await getApplicationCacheDirectory();
    final Directory dir = Directory('${cache.path}/chatflux_updates');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
    final String path = '${dir.path}/ChatFlux-$version.apk';

    final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      unawaited(
        FluxerModal.show<void>(
          context,
          title: 'ChatFlux frissítés letöltése',
          centered: true,
          useRootNavigator: true,
          builder: (BuildContext dialogContext, VoidCallback close) =>
              ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (BuildContext _, double? value, Widget? _) {
                  if (value != null && value >= 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (dialogContext.mounted) {
                        close();
                      }
                    });
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text(
                        value == null
                            ? 'Letöltés...'
                            : 'Letöltés... ${(value * 100).round()}%',
                        style: dialogContext.textStyles.bodySmall,
                      ),
                    ],
                  );
                },
              ),
        ),
      );
    }

    try {
      await Dio().download(
        url,
        path,
        onReceiveProgress: (int received, int total) {
          if (total > 0) {
            progress.value = (received / total).clamp(0.0, 0.99).toDouble();
          }
        },
      );
    } finally {
      progress.value = 1;
    }

    final bool canInstall =
        (await _channel.invokeMethod<bool>('canInstall')) ?? false;
    if (!canInstall) {
      final BuildContext? ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await FluxerModal.show<void>(
          ctx,
          title: 'Engedély szükséges',
          centered: true,
          useRootNavigator: true,
          builder: (BuildContext dialogContext, VoidCallback close) => Text(
            'A frissítés telepítéséhez engedélyezd, hogy a ChatFlux appokat '
            'telepíthessen. A következő képernyőn kapcsold be, majd lépj '
            'vissza.',
            style: dialogContext.textStyles.bodySmall.copyWith(height: 1.4),
          ),
          actionsBuilder: (void Function([void result]) pop) => [
            FluxerButton.primary(onPressed: () => pop(), label: 'Tovább'),
          ],
        );
      }
      await _channel.invokeMethod<void>('openInstallSettings');
      // Wait for the user to come back from the settings screen, then try once more.
      await _waitForResume();
      if (!((await _channel.invokeMethod<bool>('canInstall')) ?? false)) {
        return;
      }
    }
    await _channel.invokeMethod<void>('installApk', <String, String>{
      'path': path,
    });
  }

  static Future<void> _waitForResume() {
    final Completer<void> completer = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: listener.dispose,
    );
  }

  /// Compares dotted numeric versions like 2026.10.3.
  static bool _isNewer(String candidate, String current) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((String part) => int.tryParse(part) ?? 0)
        .toList();
    final List<int> a = parse(candidate);
    final List<int> b = parse(current);
    for (int i = 0; i < a.length || i < b.length; i++) {
      final int x = i < a.length ? a[i] : 0;
      final int y = i < b.length ? b[i] : 0;
      if (x != y) {
        return x > y;
      }
    }
    return false;
  }
}

class _Release {
  const _Release(this.version, this.assets);

  final String version;
  final Map<String, String> assets;
}
