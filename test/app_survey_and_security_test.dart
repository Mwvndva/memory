import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:memory_app/main.dart';
import 'package:memory_app/features/auth/auth_views.dart';
import 'package:memory_app/repositories/auth_repository.dart';
import 'package:memory_app/core/secure_storage.dart';
import 'package:memory_app/core/api_client.dart';
import 'package:memory_app/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock secure storage MethodChannel
  final Map<String, String> secureStore = {};
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (
          MethodCall methodCall,
        ) async {
          final Map<dynamic, dynamic>? args =
              methodCall.arguments as Map<dynamic, dynamic>?;
          switch (methodCall.method) {
            case 'read':
              final key = args?['key'] as String;
              return secureStore[key];
            case 'write':
              final key = args?['key'] as String;
              final value = args?['value'] as String;
              secureStore[key] = value;
              return true;
            case 'delete':
              final key = args?['key'] as String;
              secureStore.remove(key);
              return true;
            case 'readAll':
              return secureStore;
            case 'deleteAll':
              secureStore.clear();
              return true;
            case 'containsKey':
              final key = args?['key'] as String;
              return secureStore.containsKey(key);
            default:
              return null;
          }
        });
  });

  setUp(() {
    secureStore.clear();
  });

  group('Splash Screen (LoadingView) Tests', () {
    testWidgets(
      'LoadingView renders logo and transitions to LoginView after 1100ms',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            ],
            child: const MemoryApp(),
          ),
        );

        // Verify app starts at LoadingView
        await tester.pump();
        expect(find.byType(LoadingView), findsOneWidget);
        expect(find.byType(Image), findsOneWidget); // Logo image

        // Advance time by 1100ms to trigger redirection timer
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify transition to LoginView has occurred
        expect(find.byType(LoadingView), findsNothing);
        expect(find.byType(LoginView), findsOneWidget);
      },
    );
  });

  group('AuthNotifier Username Validation Unit Tests', () {
    test(
      'checkUsername validates length, characters, and reserved names',
      () async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();

        final mockAdapter = MockHttpClientAdapter();
        final dio = Dio();
        dio.httpClientAdapter = mockAdapter;

        mockAdapter.handler = (options) async {
          if (options.path == '/auth/username-check') {
            final username = options.queryParameters['username'] as String;
            final value = username.trim().replaceFirst('@', '').toLowerCase();

            if (value.length < 3) {
              return _createJsonResponse({
                'message': 'Use at least 3 characters.',
                'ok': false,
              }, 200);
            } else if (value.length > 30) {
              return _createJsonResponse({
                'message': 'Use 30 characters or fewer.',
                'ok': false,
              }, 200);
            } else if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
              return _createJsonResponse({
                'message': 'Only letters, numbers, periods, and underscores.',
                'ok': false,
              }, 200);
            } else if (value.startsWith('.') ||
                value.endsWith('.') ||
                value.contains('..')) {
              return _createJsonResponse({
                'message': 'Periods cannot start, end, or repeat.',
                'ok': false,
              }, 200);
            } else if (value == 'roy' || value == 'memory') {
              return _createJsonResponse({
                'message': '@$value is taken.',
                'ok': false,
              }, 200);
            } else {
              return _createJsonResponse({
                'message': '@$value is available.',
                'ok': true,
              }, 200);
            }
          }
          return _createJsonResponse({}, 404);
        };

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            apiClientProvider.overrideWithValue(dio),
          ],
        );
        addTearDown(container.dispose);

        final authNotifier = container.read(sessionProvider.notifier);

        // Too short
        var result = await authNotifier.checkUsername('ab');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('at least 3 characters'));

        // Too long
        result = await authNotifier.checkUsername('a' * 31);
        expect(result['ok'], isFalse);
        expect(result['message'], contains('30 characters or fewer'));

        // Invalid characters
        result = await authNotifier.checkUsername('user-name!');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('Only letters, numbers'));

        // Period issues
        result = await authNotifier.checkUsername('.username');
        expect(result['ok'], isFalse);
        expect(
          result['message'],
          contains('Periods cannot start, end, or repeat'),
        );

        result = await authNotifier.checkUsername('username.');
        expect(result['ok'], isFalse);
        expect(
          result['message'],
          contains('Periods cannot start, end, or repeat'),
        );

        result = await authNotifier.checkUsername('user..name');
        expect(result['ok'], isFalse);
        expect(
          result['message'],
          contains('Periods cannot start, end, or repeat'),
        );

        // Reserved usernames
        result = await authNotifier.checkUsername('roy');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('taken'));

        result = await authNotifier.checkUsername('memory');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('taken'));

        // Valid username
        result = await authNotifier.checkUsername('valid_user.1');
        expect(result['ok'], isTrue);
        expect(result['message'], contains('available'));
      },
    );
  });

  group('AuthNotifier Password Validation Unit Tests', () {
    test(
      'checkPassword validates length, case matching, and confirmation matching',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final authNotifier = container.read(sessionProvider.notifier);

        // Too short
        var result = authNotifier.checkPassword('Short1', 'Short1');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('at least 8 characters'));

        // Missing uppercase
        result = authNotifier.checkPassword('lowercase123', 'lowercase123');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('uppercase letter'));

        // Missing lowercase
        result = authNotifier.checkPassword('UPPERCASE123', 'UPPERCASE123');
        expect(result['ok'], isFalse);
        expect(result['message'], contains('lowercase letter'));

        // Password mismatch
        result = authNotifier.checkPassword(
          'StrongPass123!',
          'DifferentPass123!',
        );
        expect(result['ok'], isFalse);
        expect(result['message'], contains('do not match'));

        // Valid password
        result = authNotifier.checkPassword('StrongPass123!', 'StrongPass123!');
        expect(result['ok'], isTrue);
        expect(result['message'], contains('match'));
      },
    );
  });

  group('Security & API Authentication Headers Tests', () {
    test(
      'apiClientProvider injects Bearer token from secure storage',
      () async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          ],
        );
        addTearDown(container.dispose);

        // Store a dummy token in secure storage
        final storage = container.read(secureStorageProvider);
        await storage.write(key: 'auth_token', value: 'secret-token-12345');

        final dioClient = container.read(apiClientProvider);

        // Verify interceptor injects token into request options
        final options = RequestOptions(path: '/users/me');

        // Simulate interceptor execution
        final interceptor = dioClient.interceptors.firstWhere(
          (i) => i is QueuedInterceptorsWrapper,
        );

        final handler = TestRequestInterceptorHandler();
        interceptor.onRequest(options, handler);

        final modifiedOptions = await handler.completer.future;
        expect(
          modifiedOptions.headers['Authorization'],
          equals('Bearer secret-token-12345'),
        );
      },
    );
  });
}

class TestRequestInterceptorHandler extends RequestInterceptorHandler {
  final Completer<RequestOptions> completer = Completer<RequestOptions>();

  @override
  void next(RequestOptions requestOptions) {
    completer.complete(requestOptions);
  }
}

class MockHttpClientAdapter implements HttpClientAdapter {
  late Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _createJsonResponse(Map<String, dynamic> data, int statusCode) {
  final bytes = utf8.encode(json.encode(data));
  return ResponseBody(
    Stream.value(Uint8List.fromList(bytes)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
