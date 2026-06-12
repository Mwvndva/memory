import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_views.dart';
import '../features/feed/feed_views.dart';
import '../features/capture/capture_views.dart';
import '../features/circle/circle_views.dart';
import '../repositories/auth_repository.dart';

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
