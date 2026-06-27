import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'api_config.dart';
import 'secure_storage.dart';
import '../repositories/auth_repository.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<String?>? refreshFuture;

  // Configure SSL Certificate Pinning
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: true));
    client.badCertificateCallback = (cert, host, port) {
      const expectedFingerprint = String.fromEnvironment('SSL_PINNED_FINGERPRINT', defaultValue: '');
      if (expectedFingerprint.isEmpty) {
        // Fall back to standard OS-level CA certification verification if no custom fingerprint is pinned
        return false;
      }
      final fingerprint = sha256.convert(cert.der).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      return fingerprint == expectedFingerprint;
    };
    return client;
  };

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final isAnonymous = options.extra['anonymous'] == true;
          if (!isAnonymous) {
            final session = ref.read(sessionProvider);
            if (options.path == '/auth/refresh') {
              final refreshToken = session.refreshToken;
              if (refreshToken != null && refreshToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $refreshToken';
              }
            } else {
              final token = session.accessToken;
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
          }
        } catch (_) {
          // Fallback if secure storage is not ready or throws in tests
        }
        return handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401 &&
            err.requestOptions.path != '/auth/refresh' &&
            err.requestOptions.extra['isRetry'] != true) {
          
          bool shouldLogout = false;
          try {
            // Coordinate concurrent refresh operations
            refreshFuture ??= () async {
              try {
                final response = await dio.post('/auth/refresh');
                final tokens = response.data['tokens'] as Map<String, dynamic>?;
                final newAccessToken = tokens != null ? tokens['access_token'] as String? : null;
                final newRefreshToken = tokens != null ? tokens['refresh_token'] as String? : null;

                if (newAccessToken != null && newRefreshToken != null) {
                  // Centralized token update inside SessionManager
                  ref.read(sessionProvider.notifier).updateTokens(newAccessToken, newRefreshToken);

                  // Persist to secure storage
                  final storage = ref.read(secureStorageProvider);
                  await storage.write(key: 'auth_token', value: newAccessToken);
                  await storage.write(key: 'refresh_token', value: newRefreshToken);
                  
                  return newAccessToken;
                }
              } on DioException catch (refreshErr) {
                // If it's a 400, 401 or 403, the refresh token is invalid/expired/revoked
                final status = refreshErr.response?.statusCode;
                if (status == 400 || status == 401 || status == 403) {
                  shouldLogout = true;
                }
              } catch (_) {
                // Other exceptions
              }
              return null;
            }();

            final newAccessToken = await refreshFuture;
            refreshFuture = null;

            if (newAccessToken != null) {
              // Retry the original request
              final options = err.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              options.extra['isRetry'] = true;

              final response = await dio.fetch(options);
              return handler.resolve(response);
            }
          } catch (e) {
            return handler.next(DioException(
              requestOptions: err.requestOptions,
              error: e,
            ));
          }

          if (shouldLogout) {
            await ref.read(sessionProvider.notifier).handleSessionExpired();
          }
        }

        return handler.next(err);
      },
    ),
  );

  return dio;
});
