import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kYellow = Color(0xFFE8CE3F);
const kBlack = Color(0xFF000000);
// Primary text color used on light backgrounds
const kCharcoal = Color(0xFF191716);
// Background color used in dark theme surfaces
const kDarkCream = kBlack;
// Soft cream used for light-theme surfaces (previously kYellow)
const kCream = Color(0xFFFFF8EF);

const kAmber = Color(0xFFFFC857);
const kMint = Color(0xFF5ED6B3);
const kSky = Color(0xFF63B3FF);
const kLavender = Color(0xFFBBA7FF);

// SharedPreferences provider (overridden in main with the real instance).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
	throw UnimplementedError();
});

// Theme choice and dark-mode logic removed. App defaults to light theme.
final isDarkProvider = Provider<bool>((ref) => false);
