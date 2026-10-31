// ChatFlux-only preferences, kept on this device.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatFluxPrefs {
  ChatFluxPrefs._();

  static const String _animateProfilesKey = 'chatflux.animate_profiles';

  /// Animated (GIF) avatars and banners play everywhere, not only in the profile.
  static final ValueNotifier<bool> animateProfiles = ValueNotifier<bool>(true);

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      animateProfiles.value = prefs.getBool(_animateProfilesKey) ?? true;
    } on Object catch (error) {
      debugPrint('[ChatFluxPrefs] load failed: $error');
    }
  }

  static Future<void> setAnimateProfiles({required bool value}) async {
    animateProfiles.value = value;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_animateProfilesKey, value);
    } on Object catch (error) {
      debugPrint('[ChatFluxPrefs] save failed: $error');
    }
  }
}
