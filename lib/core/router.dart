import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_views.dart';
import '../features/feed/feed_views.dart';
import '../features/capture/capture_views.dart';
import '../features/circle/circle_views.dart';
import '../features/dev/dev_diagnostics.dart';
import '../repositories/auth_repository.dart';
import 'theme.dart';

// Key to hold state across routes
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
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
      final isAuth = ref.read(authProvider).isAuthenticated;
      final path = state.uri.path;

      // Loading screen doesn't block redirects
      if (path == '/loading') return null;

      // If not authenticated, force them to onboarding/login
      if (!isAuth) {
        if (path == '/login' || path == '/create' || path == '/avatar' || path == '/contacts') {
          return null;
        }
        return '/login';
      }

      // If authenticated and on onboarding/auth views, redirect to main feed
      if (path == '/login' || path == '/create' || path == '/avatar' || path == '/contacts' || path == '/') {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
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
          return MainAppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MemoryFeedView(),
            ),
          ),
          GoRoute(
            path: '/capture',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CameraCaptureView(),
            ),
          ),
          GoRoute(
            path: '/circle',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CircleChatListView(),
            ),
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
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: dark ? kBlack : kYellow,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kBlack.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: kBlack.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: dark ? kYellow : kBlack,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: dark ? kBlack : kYellow,
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
                              color: dark ? kYellow : kBlack,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: TextStyle(
                              color: (dark ? kYellow : kBlack).withValues(alpha: 0.7),
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
