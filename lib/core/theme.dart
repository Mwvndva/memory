import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kYellow = Color(0xFFFFFF00);
const kBlack = Color(0xFF000000);
const kCharcoal = kBlack;
const kDarkCream = kBlack;
const kCream = kYellow;

const kAmber = Color(0xFFFFC857);
const kMint = Color(0xFF5ED6B3);
const kSky = Color(0xFF63B3FF);
const kLavender = Color(0xFFBBA7FF);

enum ThemeChoice { system, dark, light }

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ThemeNotifier extends StateNotifier<ThemeChoice> {
  ThemeNotifier(this._prefs) : super(ThemeChoice.system) {
    _loadTheme();
  }

  final SharedPreferences _prefs;
  static const _key = 'theme_choice';

  void _loadTheme() {
    final val = _prefs.getString(_key);
    if (val != null) {
      state = ThemeChoice.values.firstWhere(
        (e) => e.name == val,
        orElse: () => ThemeChoice.system,
      );
    }
  }

  void setTheme(ThemeChoice choice) {
    state = choice;
    _prefs.setString(_key, choice.name);
  }
}

final themeChoiceProvider = StateNotifierProvider<ThemeNotifier, ThemeChoice>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class SystemBrightnessNotifier extends StateNotifier<Brightness> with WidgetsBindingObserver {
  SystemBrightnessNotifier() : super(WidgetsBinding.instance.platformDispatcher.platformBrightness) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    state = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final systemBrightnessProvider = StateNotifierProvider<SystemBrightnessNotifier, Brightness>((ref) {
  return SystemBrightnessNotifier();
});

final isDarkProvider = Provider<bool>((ref) {
  final choice = ref.watch(themeChoiceProvider);
  if (choice == ThemeChoice.dark) return true;
  if (choice == ThemeChoice.light) return false;
  
  final systemBrightness = ref.watch(systemBrightnessProvider);
  return systemBrightness == Brightness.dark;
});
