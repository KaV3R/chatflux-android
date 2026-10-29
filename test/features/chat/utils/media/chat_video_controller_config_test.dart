import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/features/chat/utils/media/chat_video_controller_config.dart';

void main() {
  test('Android chat video asks for direct MediaCodec before the copy mode '
      '(auto-safe only ever picks the per-frame copy on our libmpv)', () {
    final configuration = chatVideoControllerConfigurationFor(
      TargetPlatform.android,
    );

    expect(configuration.hwdec, 'mediacodec,mediacodec-copy');
    expect(configuration.vo, isNull);
  });

  for (final TargetPlatform platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.linux,
    TargetPlatform.windows,
  ]) {
    test('${platform.name} chat video keeps media_kit defaults instead of '
        'Android-only decoder names', () {
      final configuration = chatVideoControllerConfigurationFor(platform);

      expect(configuration.hwdec, isNull);
      expect(configuration.vo, isNull);
    });
  }
}
