import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'token_store.dart';

/// A readable error for the UI (SnackBar text).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool offline; // true = could not reach the server at all
  ApiException(this.message, [this.statusCode, this.offline = false]);
  @override
  String toString() => message;
}

String _readDetail(dynamic data, int? code) {
  if (data is Map && data['detail'] != null) {
    final d = data['detail'];
    if (d is String) return d;
    if (d is Map) {
      final items = d['items'];
      final base = (d['message'] ?? 'Error').toString();
      if (items is List && items.isNotEmpty) return '$base:\n${items.join('\n')}';
      return base;
    }
    if (d is List) {
      return d
          .map((e) {
            if (e is Map) {
              final loc = (e['loc'] is List) ? (e['loc'] as List).last : '';
              return '$loc: ${e['msg']}';
            }
            return e.toString();
          })
          .join('\n');
    }
  }
  if (code == 429) return 'Limit reached. Try again later.';
  return 'Something went wrong (${code ?? 'no connection'}).';
}

class ApiClient {
  final TokenStore store;
  final void Function() onSessionExpired;
  late final Dio dio;
  final Dio _plain = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
  ));

  ApiClient(this.store, this.onSessionExpired) {
    dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 8), // offline / wrong Wi-Fi fails fast instead of spinning
      receiveTimeout: const Duration(seconds: 25), // AI calls override this to 60s
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await store.access;
        if (t != null && o.extra['noAuth'] != true) {
          o.headers['Authorization'] = 'Bearer $t';
        }
        h.next(o);
      },
      onError: (e, h) async {
        final req = e.requestOptions;
        final isAuthCall = req.path.startsWith('/api/auth/login') ||
            req.path.startsWith('/api/auth/register') ||
            req.path.startsWith('/api/auth/refresh');
        if (e.response?.statusCode == 401 && !isAuthCall && req.extra['retried'] != true) {
          final ok = await _tryRefresh();
          if (ok) {
            req.extra['retried'] = true;
            req.headers['Authorization'] = 'Bearer ${await store.access}';
            try {
              return h.resolve(await dio.fetch(req));
            } on DioException catch (e2) {
              return h.next(e2);
            }
          }
          onSessionExpired();
        }
        h.next(e);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final r = await store.refresh;
    if (r == null) return false;
    try {
      final res = await _plain.post('/api/auth/refresh', data: {'refresh': r});
      await store.save(access: res.data['access'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs a request and converts any failure into [ApiException].
  Future<T> call<T>(Future<Response<dynamic>> Function() send, T Function(dynamic data) parse) async {
    try {
      final res = await send();
      return parse(res.data);
    } on DioException catch (e) {
      final unreachable = e.response == null &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout);
      if (unreachable) {
        throw ApiException(
          'No internet connection or the server cannot be reached.\n'
          'Check your Wi-Fi / mobile data and try again.'
          '${kDebugMode ? '\n($apiBaseUrl)' : ''}',
          null,
          true,
        );
      }
      throw ApiException(_readDetail(e.response?.data, e.response?.statusCode), e.response?.statusCode);
    }
  }
}
