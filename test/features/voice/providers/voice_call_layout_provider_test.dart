import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/features/voice/providers/voice_call_layout_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  VoiceCallLayoutState state() => container.read(voiceCallLayoutProvider);
  VoiceCallLayout notifier() =>
      container.read(voiceCallLayoutProvider.notifier);

  test('pin keeps grid mode and sets pinned tile', () {
    notifier().pin('tile-1');
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, 'tile-1');
  });

  test('pin again in grid clears the pin', () {
    notifier().pin('tile-1');
    notifier().pin('tile-1');
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, isNull);
  });

  test('pin in focus mode sets pinned tile without leaving focus', () {
    notifier().setMode(VoiceCallLayoutMode.focus);
    notifier().pin('tile-1');
    expect(state().mode, VoiceCallLayoutMode.focus);
    expect(state().pinnedTileId, 'tile-1');
  });

  test('setMode grid clears pin and keeps expanded users', () {
    notifier().toggleExpandedUser('user-1');
    notifier().pin('tile-1');
    notifier().setMode(VoiceCallLayoutMode.grid);
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, isNull);
    expect(state().expandedUserIds, <String>{'user-1'});
  });

  test('unpin from focus returns to grid', () {
    notifier().toggleExpandedUser('user-1');
    notifier().setMode(VoiceCallLayoutMode.focus);
    notifier().pin('tile-1');
    notifier().unpin();
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, isNull);
    expect(state().expandedUserIds, <String>{'user-1'});
  });

  test('unpin in grid clears pin only', () {
    notifier().pin('tile-1');
    notifier().unpin();
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, isNull);
  });

  test('clearStalePin drops the pin without flipping mode', () {
    notifier().pin('tile-1');
    notifier().clearStalePin();
    expect(state().mode, VoiceCallLayoutMode.grid);
    expect(state().pinnedTileId, isNull);
  });

  test('setMode focus does not invent a pin', () {
    notifier().setMode(VoiceCallLayoutMode.focus);
    expect(state().mode, VoiceCallLayoutMode.focus);
    expect(state().pinnedTileId, isNull);
  });
}
