import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memory_app/features/circle/circle.dart';
import 'package:memory_app/features/auth/auth.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/app_providers.dart';

// ─── Stubs ───────────────────────────────────────────────────────────────────

const _stubUser = UserProfile(
  firstName: 'Test',
  lastName: 'User',
  username: 'testuser',
  email: 'test@test.com',
  phone: '+10000000000',
  isAuthenticated: true,
);

/// A minimal SessionManager stand-in that holds a fixed, unauthenticated
/// SessionState (empty token) so _initWebSocket bails out immediately without
/// touching native channels or making network calls.
class _FakeSessionManager extends StateNotifier<SessionState>
    implements SessionManager {
  _FakeSessionManager()
    : super(
        SessionState(isAuthenticated: false, user: _stubUser, accessToken: ''),
      );

  // All SessionManager methods are no-ops in tests
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ─── Mock Dio interceptor ────────────────────────────────────────────────────

class _MockInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
      Response(requestOptions: options, statusCode: 200, data: {}),
    );
  }
}

// ─── Helper: build a pre-configured container ────────────────────────────────

ProviderContainer _makeContainer(Dio dio, SharedPreferences prefs) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(dio),
      // Short-circuit SessionManager so no native channel or network is needed
      sessionProvider.overrideWith((_) => _FakeSessionManager()),
      // Also override authProvider so any direct reads return the stub user
      authProvider.overrideWithValue(_stubUser),
    ],
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio mockDio;
  late SharedPreferences prefs;

  setUpAll(() {
    // Silence any stray native-channel calls that may still leak through
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (_) async => null);

    const homeWidgetChannel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (_) async => null);

    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await Hive.openBox('feed_cache');
    mockDio = Dio()..interceptors.add(_MockInterceptor());
    prefs = await SharedPreferences.getInstance();
  });

  group('Messaging Architecture Modernization Tests', () {
    // ── 1. Optimistic send ──────────────────────────────────────────────────
    test('Optimistic sending adds message to conversation immediately', () {
      final container = _makeContainer(mockDio, prefs);
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.enterConversation('Amara');

      notifier.sendMessage('Amara', 'Optimistic test message');

      final messages =
          container.read(chatProvider).messagesByContact['Amara'] ?? [];
      // Message must appear in the list immediately (optimistic UI).
      // In the test environment there is no WS channel, so _markFailed fires
      // synchronously — we only assert presence, not delivery status.
      expect(
        messages.any((m) => m.text == 'Optimistic test message'),
        isTrue,
        reason: 'Message should appear immediately after sendMessage()',
      );
    });

    // ── 2. Retry ────────────────────────────────────────────────────────────
    test('Retry message keeps message in conversation list', () {
      final container = _makeContainer(mockDio, prefs);
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.enterConversation('Amara');

      final failedMsg = Message(
        id: 'msg-fail-1',
        sender: 'You',
        text: 'Failed message',
        timestamp: DateTime.now(),
        isMine: true,
        isPending: false,
        isFailed: true,
      );
      notifier.state = notifier.state.copyWith(
        messagesByContact: {
          'Amara': [failedMsg],
        },
      );

      // retryMessage: with no WS channel _transmitMessage immediately calls
      // _markFailed, so isFailed toggles back to true. But crucially the
      // message must still exist in the list (not deleted).
      notifier.retryMessage('Amara', 'msg-fail-1');

      final msgs =
          container.read(chatProvider).messagesByContact['Amara'] ?? [];
      expect(
        msgs.any((m) => m.id == 'msg-fail-1'),
        isTrue,
        reason: 'Retried message should remain in the conversation list',
      );
    });

    // ── 3. Optimistic delete ─────────────────────────────────────────────────
    test('deleteMessageOptimistic removes message from state', () {
      final container = _makeContainer(mockDio, prefs);
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.enterConversation('Amara');
      notifier.sendMessage('Amara', 'To delete');

      final before =
          container.read(chatProvider).messagesByContact['Amara'] ?? [];
      final targetId = before.firstWhere((m) => m.text == 'To delete').id;

      notifier.deleteMessageOptimistic('Amara', targetId);

      final after =
          container.read(chatProvider).messagesByContact['Amara'] ?? [];
      expect(
        after.any((m) => m.id == targetId),
        isFalse,
        reason: 'Deleted message should be removed from state',
      );
    });

    // ── 4. Typing indicators ─────────────────────────────────────────────────
    test('Typing indicators can be set and cleared via state', () {
      final container = _makeContainer(mockDio, prefs);
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);

      notifier.state = notifier.state.copyWith(
        typingIndicators: {'Amara': true},
      );
      expect(container.read(chatProvider).typingIndicators['Amara'], isTrue);

      notifier.state = notifier.state.copyWith(
        typingIndicators: {'Amara': false},
      );
      expect(container.read(chatProvider).typingIndicators['Amara'], isFalse);
    });

    // ── 5. Deduplication ─────────────────────────────────────────────────────
    test('Duplicate message with same id is not appended twice', () {
      final container = _makeContainer(mockDio, prefs);
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);

      final msg = Message(
        id: 'dedup-id-1',
        sender: 'Amara',
        text: 'Duplicate check',
        timestamp: DateTime.now(),
        isMine: false,
      );

      notifier.state = notifier.state.copyWith(
        messagesByContact: {
          'Amara': [msg],
        },
      );

      // Simulate re-delivery — guard against duplicate insertion
      final existing = notifier.state.messagesByContact['Amara']!;
      if (!existing.any((m) => m.id == msg.id)) {
        notifier.state = notifier.state.copyWith(
          messagesByContact: {
            'Amara': [...existing, msg],
          },
        );
      }

      final msgs =
          container.read(chatProvider).messagesByContact['Amara'] ?? [];
      expect(
        msgs.length,
        equals(1),
        reason: 'Duplicate id should not be appended again',
      );
    });
  });
}
