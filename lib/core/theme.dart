import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kCream = Color(0xFFFFF8EF);
const kPaper = Color(0xFFFFFFFF);
const kCoral = Color(0xFFFF6B57);
const kCoralDark = Color(0xFFE84F3B);
const kAmber = Color(0xFFFFC857);
const kMint = Color(0xFF5ED6B3);
const kSky = Color(0xFF63B3FF);
const kLavender = Color(0xFFBBA7FF);
const kCharcoal = Color(0xFF292421);
const kDarkPaper = Color(0xFF25211F);
const kDarkCream = Color(0xFF191716);

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

final isDarkProvider = Provider<bool>((ref) {
  final choice = ref.watch(themeChoiceProvider);
  if (choice == ThemeChoice.dark) return true;
  if (choice == ThemeChoice.light) return false;
  
  // System theme fallback context-free
  final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return platform == Brightness.dark;
});
