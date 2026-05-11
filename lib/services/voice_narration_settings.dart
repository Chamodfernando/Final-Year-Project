import 'package:shared_preferences/shared_preferences.dart';

class VoiceNarrationSettings {
  static const String keyLocale = 'voice_narration_locale';
  static const String keyRate = 'voice_narration_rate';

  static const String defaultLocale = 'en-US';
  static const double defaultRate = 0.45;

  static Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLocale) ?? defaultLocale;
  }

  static Future<double> getRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(keyRate) ?? defaultRate;
  }

  static Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLocale, locale);
  }

  static Future<void> setRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyRate, rate);
  }
}
