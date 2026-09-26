// DDE-Mart customer app — HTTP layer (original).
//
// Dio client for the DDE-Mart API v1 (see admin-panel/docs/api-v1.md).
// Auth tokens are attached per request; API errors surface as [ApiException]
// with the backend's message so screens can show it directly.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => 'ApiException($status): $message';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(authStoreProvider.notifier).token();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final response = error.response;
        if (response != null) {
          final data = response.data;
          final message = data is Map && data['message'] is String
              ? data['message'] as String
              : 'Request failed (${response.statusCode}).';
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              error: ApiException(message, status: response.statusCode),
            ),
          );
          return;
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

/// Unwraps a Dio error into a human message for snackbars.
String apiMessage(Object error) {
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).message;
  }
  return 'Something went wrong. Please try again.';
}

/// Absolute URL for backend asset paths. The API mixes absolute CDN links
/// with app-relative storage paths — resolve the latter against the API
/// host actually in use (LAN IP on device, localhost on emulator).
String? resolveAsset(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = Uri.parse(AppConfig.apiBaseUrl);
  final host = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
  return '$host${path.startsWith('/') ? '' : '/'}$path';
}

/// GET /app-config payload (public launch gate).
class LaunchConfig {
  LaunchConfig({
    required this.maintenance,
    required this.minVersions,
    required this.supportEmail,
    required this.supportPhone,
  });

  factory LaunchConfig.fromJson(Map<String, dynamic> json) {
    final min = (json['min_versions'] as Map?) ?? {};
    final support = (json['support'] as Map?) ?? {};
    return LaunchConfig(
      maintenance: json['maintenance'] == true,
      minVersions: {
        'customer': '${min['customer'] ?? '1.0.0'}',
        'driver': '${min['driver'] ?? '1.0.0'}',
        'vendor': '${min['vendor'] ?? '1.0.0'}',
      },
      supportEmail: '${support['email'] ?? ''}',
      supportPhone: '${support['phone'] ?? ''}',
    );
  }

  final bool maintenance;
  final Map<String, String> minVersions;
  final String supportEmail;
  final String supportPhone;
}
