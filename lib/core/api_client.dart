import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';
import 'secure_storage.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // Configure SSL Certificate Pinning
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: true));
    client.badCertificateCallback = (cert, host, port) {
      const expectedFingerprint = String.fromEnvironment('SSL_PINNED_FINGERPRINT', defaultValue: '');
      if (expectedFingerprint.isEmpty) {
        // Fall back to standard OS-level CA certification verification if no custom fingerprint is pinned
        return false;
      }
      final fingerprint = cert.sha256.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
      return fingerprint == expectedFingerprint;
    };
    return client;
  };

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final storage = ref.read(secureStorageProvider);
          final token = await storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {
          // Fallback if secure storage is not ready or throws in tests
        }
        return handler.next(options);
      },
    ),
  );

  return dio;
});

