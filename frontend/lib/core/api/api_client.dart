import 'package:dio/dio.dart';
import '../constants.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';
import 'auth_token_store.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    AuthTokenStore? tokenStore,
    required Future<void> Function() onUnauthenticated,
  }) : tokenStore = tokenStore ?? AuthTokenStore(),
       dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: Constants.apiBaseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
               headers: {'Content-Type': 'application/json'},
             ),
           ) {
    this.dio.interceptors.add(
      AuthInterceptor(
        dio: this.dio,
        tokenStore: this.tokenStore,
        onUnauthenticated: onUnauthenticated,
      ),
    );
  }

  final Dio dio;
  final AuthTokenStore tokenStore;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<T>(path, queryParameters: query));
  Future<Response<T>> post<T>(String path, {Object? body}) =>
      _wrap(() => dio.post<T>(path, data: body));
  Future<Response<T>> patch<T>(String path, {Object? body}) =>
      _wrap(() => dio.patch<T>(path, data: body));
  Future<Response<T>> delete<T>(String path) =>
      _wrap(() => dio.delete<T>(path));

  Future<Response<T>> _wrap<T>(Future<Response<T>> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  /// A readable message for django-ninja's request-validation body,
  /// `{"detail": [{"loc": ["body", "payload", "email"], "msg": "..."}]}`:
  /// the first problem, prefixed with the field it's about.
  static String _validationMessage(List<dynamic> detail) {
    final first = detail.isEmpty ? null : detail.first;
    if (first is! Map || first['msg'] == null) return 'Invalid request';
    final loc = first['loc'];
    final field = loc is List && loc.isNotEmpty ? loc.last : null;
    final where = field is String && field != 'payload' && field != 'body'
        ? '$field: '
        : '';
    return '$where${first['msg']}';
  }

  ApiException _toApi(DioException e) {
    final resp = e.response;
    if (resp == null) return ApiNetworkException(e.message ?? 'Network error');
    final body = resp.data is Map ? resp.data as Map : null;
    final err = body?['error'] is Map ? body!['error'] as Map : null;
    final detail = body?['detail'];
    final msg =
        err?['message']?.toString() ??
        (detail is List ? _validationMessage(detail) : detail?.toString()) ??
        'Request failed';
    final det = err?['details'] ?? detail;
    switch (resp.statusCode) {
      case 401:
        return ApiAuthException(msg, det);
      case 403:
        return ApiForbiddenException(msg, det);
      case 404:
        return ApiNotFoundException(msg, det);
      case 409:
        return ApiConflictException(msg, det);
      case 422:
        return ApiValidationException(msg, det);
      case 502:
        return ApiUpstreamException(msg, det);
      default:
        return resp.statusCode! >= 500
            ? ApiServerException(msg, det)
            : ApiValidationException(msg, det);
    }
  }
}
