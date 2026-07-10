import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/features/feed/feed.dart';
import 'package:memory_app/features/capture/capture.dart';
import 'package:memory_app/features/circle/circle.dart';
import '../features/dev/views/dev_diagnostics.dart';
import 'package:memory_app/features/notification/notification.dart';
import 'package:memory_app/design_system/design_system.dart';

// Key to hold state across routes
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.isRestoring != next.isRestoring) {
        notifyListeners();
      }
    });
  }
}

final routerRefreshNotifierProvider = Provider<GoRouterRefreshNotifier>((ref) {
  return GoRouterRefreshNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/loading',
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final isRestoring = session.isRestoring;
      final isAuth = session.isAuthenticated;
      final path = state.uri.path;

      // While restoring session, hold the user on /loading
      if (isRestoring) {
        return '/loading';
      }

      // Once finished restoring, route from loading to correct home/login
      if (path == '/loading') {
        return isAuth ? '/capture' : '/login';
      }

      // If not authenticated, force them to onboarding/login
      if (!isAuth) {
        if (path == '/login' ||
            path == '/create' ||
            path == '/avatar' ||
            path == '/contacts') {
          return null;
        }
        return '/login';
      }

      // If authenticated and on onboarding/auth views, redirect to main capture
      if (path == '/login' ||
          path == '/create' ||
          path == '/avatar' ||
          path == '/contacts' ||
          path == '/') {
        return '/capture';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingView(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(
        path: '/create',
        builder: (context, state) => const CreateAccountView(),
      ),
      GoRoute(
        path: '/avatar',
        builder: (context, state) => const AvatarUploadView(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsSetupView(),
      ),
      // Dev-only diagnostics
      GoRoute(
        path: '/dev/diagnostics',
        builder: (context, state) => const DevDiagnosticsView(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          // The shell adds no chrome of its own; the child is the screen.
          return child;
        },
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MemoryFeedView()),
          ),
          GoRoute(
            path: '/capture',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CameraCaptureView()),
          ),
          GoRoute(
            path: '/circle',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CircleChatListView()),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:name',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final name = state.pathParameters['name'] ?? 'Contact';
          return ChatInboxView(contactName: name);
        },
      ),
      GoRoute(
        path: '/memory/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MemoryDetailScreen(memoryId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationScreen(),
      ),
    ],
  );
});

void showGlobalNotification({
  required String title,
  required String body,
  required VoidCallback onTap,
}) {
  final overlayState = rootNavigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -60 * (1 - value)),
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: dark ? MemoryColors.ink : MemoryColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: MemoryColors.ink.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: MemoryColors.ink.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: dark ? MemoryColors.accent : MemoryColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: dark ? MemoryColors.ink : MemoryColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: dark
                                  ? MemoryColors.accent
                                  : MemoryColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: TextStyle(
                              color:
                                  (dark
                                          ? MemoryColors.accent
                                          : MemoryColors.ink)
                                      .withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlayState.insert(overlayEntry);

  // Automatically dismiss after 4 seconds
  Timer(const Duration(seconds: 4), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}
