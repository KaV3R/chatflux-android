import 'package:shared_preferences/shared_preferences.dart';

const String _kAndroidAlternateAppIconNameKey =
    'android_alternate_app_icon_name';

Future<String?> readAndroidAlternateAppIconPreference() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final String? value = preferences.getString(_kAndroidAlternateAppIconNameKey);
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

Future<void> writeAndroidAlternateAppIconPreference(String? iconName) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (iconName == null || iconName.isEmpty) {
    await preferences.remove(_kAndroidAlternateAppIconNameKey);
    return;
  }
  await preferences.setString(_kAndroidAlternateAppIconNameKey, iconName);
}
