import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/core/api/auth_interceptor.dart';
import 'package:frontend/core/constants.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi(accessToken: 'tok'));

  group('HTTP verbs', () {
    test('get sends query parameters', () async {
      api.enqueue(200, {'ok': true});
      final r = await api.client.get<Map<String, dynamic>>(
        '/things',
        query: {'a': '1'},
      );
      expect(api.last.method, 'GET');
      expect(api.last.query, {'a': '1'});
      expect(r.data, {'ok': true});
    });

    test('post, patch and delete send the right method and body', () async {
      api.enqueue(201, {'id': 1});
      api.enqueue(200, {'id': 1});
      api.enqueue(204);

      await api.client.post<Map<String, dynamic>>('/x', body: {'n': 1});
      await api.client.patch<Map<String, dynamic>>('/x/1', body: {'n': 2});
      await api.client.delete<void>('/x/1');

      expect(api.requests.map((r) => '${r.method} ${r.path} ${r.body}'), [
        'POST /x {n: 1}',
        'PATCH /x/1 {n: 2}',
        'DELETE /x/1 null',
      ]);
    });

    test('attaches the bearer token from the token store', () async {
      api.enqueue(200, <dynamic>[]);
      await api.client.get<List<dynamic>>('/accounts');
      expect(api.last.options.headers['Authorization'], 'Bearer tok');
    });

    test('never attaches a token to /auth/ endpoints', () async {
      api.enqueue(200, {'access': 'a', 'refresh': 'r'});
      await api.client.post<Map<String, dynamic>>('/auth/login', body: {});
      expect(api.last.options.headers, isNot(contains('Authorization')));
    });
  });

  group('error mapping', () {
    final cases = <int, TypeMatcher<ApiException>>{
      400: isA<ApiValidationException>(),
      403: isA<ApiForbiddenException>(),
      404: isA<ApiNotFoundException>(),
      409: isA<ApiConflictException>(),
      422: isA<ApiValidationException>(),
      500: isA<ApiServerException>(),
      502: isA<ApiUpstreamException>(),
      503: isA<ApiServerException>(),
    };

    cases.forEach((status, matcher) {
      test('$status maps to ${matcher.runtimeType}', () async {
        api.enqueue(status, {'detail': 'nope'});
        await expectLater(
          api.client.get<dynamic>('/x'),
          throwsA(matcher.having((e) => e.message, 'message', 'nope')),
        );
      });
    });

    test('a 401 on an /auth/ route maps to ApiAuthException', () async {
      api.enqueue(401, {'detail': 'bad credentials'});
      await expectLater(
        api.client.post<dynamic>('/auth/login', body: {}),
        throwsA(
          isA<ApiAuthException>()
              .having((e) => e.code, 'code', 'auth_error')
              .having((e) => e.message, 'message', 'bad credentials'),
        ),
      );
    });

    test('prefers the {"error": {message, details}} envelope', () async {
      api.enqueue(409, {
        'error': {
          'code': 'conflict',
          'message': 'Already linked',
          'details': {'account_id': 'acc-1'},
        },
        'detail': 'ignored',
      });
      await expectLater(
        api.client.post<dynamic>('/x', body: {}),
        throwsA(
          isA<ApiConflictException>()
              .having((e) => e.message, 'message', 'Already linked')
              .having((e) => e.details, 'details', {'account_id': 'acc-1'}),
        ),
      );
    });

    test('keeps a list-shaped detail (django-ninja 422s) as details', () async {
      final detail = [
        {
          'loc': ['body', 'name'],
          'msg': 'Field required',
        },
      ];
      api.enqueue(422, {'detail': detail});
      await expectLater(
        api.client.post<dynamic>('/x', body: {}),
        throwsA(
          isA<ApiValidationException>().having(
            (e) => e.details,
            'details',
            detail,
          ),
        ),
      );
    });

    test('falls back to a generic message for non-JSON bodies', () async {
      api.enqueue(500, 'Internal Server Error');
      await expectLater(
        api.client.get<dynamic>('/x'),
        throwsA(
          isA<ApiServerException>()
              .having((e) => e.message, 'message', 'Request failed')
              .having((e) => e.details, 'details', isNull),
        ),
      );
    });

    test('a transport failure maps to ApiNetworkException', () async {
      api.adapter.enqueueNetworkError();
      await expectLater(
        api.client.get<dynamic>('/x'),
        throwsA(
          isA<ApiNetworkException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.message, 'message', 'boom'),
        ),
      );
    });

    test('a 401 with no refresh token signs the user out', () async {
      api.enqueue(401, {'detail': 'expired'});
      await expectLater(
        api.client.get<dynamic>('/accounts'),
        throwsA(isA<ApiAuthException>()),
      );
      expect(api.unauthenticatedCalls, 1);
    });
  });

  test('ApiException.toString includes the code and message', () {
    expect(
      const ApiNotFoundException('gone').toString(),
      'ApiException(not_found): gone',
    );
  });

  test('builds a default Dio with the configured base URL and timeouts', () {
    final client = ApiClient(
      tokenStore: MockTokenStore(),
      onUnauthenticated: () async {},
    );
    expect(client.dio.options.baseUrl, Constants.apiBaseUrl);
    expect(client.dio.options.connectTimeout, const Duration(seconds: 10));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
    expect(client.dio.options.headers['Content-Type'], 'application/json');
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
  });

  test('accepts an injected Dio as-is', () {
    final dio = Dio(BaseOptions(baseUrl: 'http://custom'));
    final client = ApiClient(
      dio: dio,
      tokenStore: MockTokenStore(),
      onUnauthenticated: () async {},
    );
    expect(identical(client.dio, dio), isTrue);
  });
}
