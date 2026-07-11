import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences instance, overridden in `main` with the real one.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// Whether the app renders its dark surfaces.
///
/// Dark mode is not user-selectable yet; this is the single seam every widget
/// reads, so turning it on later is a one-line change rather than a sweep.
final isDarkProvider = Provider<bool>((ref) => false);
