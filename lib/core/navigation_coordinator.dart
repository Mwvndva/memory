import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';

class NavigationCoordinator {
  NavigationCoordinator(this._ref);

  final Ref _ref;

  GoRouter get _router => _ref.read(routerProvider);

  void go(String location, {Object? extra}) {
    _router.go(location, extra: extra);
  }

  void push(String location, {Object? extra}) {
    _router.push(location, extra: extra);
  }

  void pop() {
    if (_router.canPop()) {
      _router.pop();
    }
  }

  void openMemory(String memoryId) {
    push('/memory/$memoryId');
  }

  void openChat(String contactName) {
    push('/chat/$contactName');
  }

  void openFeed() {
    go('/feed');
  }

  void openCapture() {
    go('/capture');
  }

  void openCircle() {
    go('/circle');
  }

  void openNotifications() {
    push('/notifications');
  }
}

final navigationCoordinatorProvider = Provider<NavigationCoordinator>((ref) {
  return NavigationCoordinator(ref);
});
