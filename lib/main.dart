import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/capture/capture_views.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-cache hardware cameras asynchronously
  preloadCameras();

  await Hive.initFlutter();
  await Hive.openBox('feed_cache');

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MemoryApp(),
    ),
  );
}

class MemoryApp extends ConsumerWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Memory',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.light().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: kYellow, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: kYellow, brightness: Brightness.dark),
      ),
      routerConfig: router,
      builder: (context, child) {
        final viewport = MediaQuery.sizeOf(context);
        final useDeviceViewport = viewport.width < 430;
        final dark = ref.watch(isDarkProvider);
        final bg = dark ? kDarkCream : kCream;

        return Scaffold(
          backgroundColor: bg,
          resizeToAvoidBottomInset: false,
          body: Center(
            child: SizedBox(
              width: useDeviceViewport ? viewport.width : 390,
              height: useDeviceViewport ? viewport.height : 844,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(useDeviceViewport ? 0 : 34),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
