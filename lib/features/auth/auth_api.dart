// DDE-Mart customer app — auth API (original).
//
// Mirrors POST /api/v1/auth/* and DELETE /me from admin-panel/docs/api-v1.md.
// Methods return the backend `data` payloads; callers persist them via
// [AuthStore]. Keeps HTTP and state cleanly separated.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

typedef AuthPayload = Map<String, dynamic>;

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthPayload> _data(Response response) async {
    return Map<String, dynamic>.from(
      (response.data as Map)['data'] as Map,
    );
  }

  Future<AuthPayload> register({
    required String name,
    required String phone,
  }) async {
    return _data(
      await _dio.post('/auth/register', data: {'name': name, 'phone': phone}),
    );
  }

  Future<AuthPayload> login({
    required String phone,
    required String password,
  }) async {
    return _data(
      await _dio.post('/auth/login', data: {'phone': phone, 'password': password}),
    );
  }

  /// Returns the debug code outside production (emulator convenience).
  Future<String?> otpRequest(String phone) async {
    final data = await _data(
      await _dio.post('/auth/otp/request', data: {'phone': phone}),
    );
    return data['debug_code'] as String?;
  }

  Future<AuthPayload> otpVerify({
    required String phone,
    required String code,
  }) async {
    return _data(
      await _dio.post('/auth/otp/verify', data: {'phone': phone, 'code': code}),
    );
  }

  Future<String?> passwordRequest(String phone) async {
    final data = await _data(
      await _dio.post('/auth/password/request', data: {'phone': phone}),
    );
    return data['debug_code'] as String?;
  }

  Future<AuthPayload> passwordReset({
    required String phone,
    required String code,
    required String password,
  }) async {
    return _data(
      await _dio.post('/auth/password/reset', data: {
        'phone': phone,
        'code': code,
        'password': password,
        'password_confirmation': password,
      }),
    );
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
  }

  Future<void> deleteAccount({String? password}) async {
    await _dio.delete('/me', data: {'password': password});
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
