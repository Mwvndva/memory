import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:memory_app/core/router.dart';
import 'package:memory_app/core/app_providers.dart';
import 'package:memory_app/features/capture/capture.dart';
import 'firebase_options.dart';
import 'package:memory_app/realtime/realtime_providers.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/design_system/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

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
    final session = ref.watch(sessionProvider);
    if (session.isAuthenticated) {
      ref.watch(pushNotificationRepositoryProvider);
      // Bootstrap the Realtime Coordinator only for authenticated sessions.
      ref.watch(realtimeCoordinatorProvider);
    }
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Memory',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.light().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: MemoryColors.accent,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: MemoryColors.accent,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
      builder: (context, child) {
        final viewport = MediaQuery.sizeOf(context);
        final useDeviceViewport = viewport.width < 430;
        final dark = ref.watch(isDarkProvider);
        final bg = dark ? MemoryColors.ink : MemoryColors.cream;

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
