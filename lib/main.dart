import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/router.dart';
import 'core/theme.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: kCoral, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: kCoral, brightness: Brightness.dark),
      ),
      routerConfig: router,
      builder: (context, child) {
        final viewport = MediaQuery.sizeOf(context);
        final useDeviceViewport = viewport.width < 430;
        final dark = ref.watch(isDarkProvider);
        final bg = dark ? const Color(0xFF11100F) : const Color(0xFFFFF4E4);

        return Scaffold(
          backgroundColor: bg,
          resizeToAvoidBottomInset: true,
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
