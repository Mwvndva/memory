import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/error_handler.dart';

class CircleInvitationService {
  CircleInvitationService(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> inviteMember(String memberId) async {
    if (kUseMockBackend) {
      return {'ok': true, 'message': 'Request sent (mock)'};
    }
    final dio = _ref.read(apiClientProvider);
    try {
      final resp = await dio.post('/circles/requests', data: {'memberId': memberId});
      final data = resp.data;
      return {
        'ok': true,
        'message': data is Map && data['message'] != null ? data['message'] : 'Request sent',
        'status': resp.statusCode,
      };
    } catch (e, stack) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Fallback to older circles/members endpoint
        try {
          final response = await dio.post('/circles/members', data: {'memberId': memberId});
          final data = response.data;
          return {
            'ok': true,
            'message': data is Map && data['message'] != null ? data['message'] : 'Member added',
            'status': response.statusCode,
          };
        } catch (e2, stack2) {
          final mapped = mapException(e2, stack2);
          return {
            'ok': false,
            'message': mapped.message,
            'status': e2 is DioException ? e2.response?.statusCode : null,
          };
        }
      }
      final mapped = mapException(e, stack);
      return {
        'ok': false,
        'message': mapped.message,
        'status': e is DioException ? e.response?.statusCode : null,
      };
    }
  }

  Future<bool> acceptRequest(String senderId) async {
    if (kUseMockBackend) return true;
    final dio = _ref.read(apiClientProvider);
    try {
      await dio.post('/circles/requests/accept', data: {'senderId': senderId});
      return true;
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  Future<bool> declineRequest(String senderId) async {
    if (kUseMockBackend) return true;
    final dio = _ref.read(apiClientProvider);
    try {
      await dio.post('/circles/requests/decline', data: {'senderId': senderId});
      return true;
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }

  Future<bool> removeMember(String memberId) async {
    if (kUseMockBackend) return true;
    final dio = _ref.read(apiClientProvider);
    try {
      await dio.delete('/circles/members/$memberId');
      return true;
    } catch (e, stack) {
      throw mapException(e, stack);
    }
  }
}

final circleInvitationServiceProvider = Provider<CircleInvitationService>((ref) {
  return CircleInvitationService(ref);
});
