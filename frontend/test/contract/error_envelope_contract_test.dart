// Error contract: how the client reads the API's error bodies.
//
// These aren't in openapi.json. The backend pins the same shapes in
// backend/apps/common/tests/test_error_envelopes.py, so a change on either side
// shows up there or here.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';

import '../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  setUp(() => api = FakeApi(accessToken: 'token'));

  Future<ApiException> failWith(int status, Object? body) async {
    api.enqueue(status, body);
    try {
      await api.client.post<dynamic>('/anything', body: const {});
    } on ApiException catch (e) {
      return e;
    }
    fail('expected an ApiException');
  }

  group('the app\'s {"error": {code, message, details}} envelope', () {
    final cases = <int, TypeMatcher<ApiException>>{
      401: isA<ApiAuthException>(),
      403: isA<ApiForbiddenException>(),
      404: isA<ApiNotFoundException>(),
      409: isA<ApiConflictException>(),
      502: isA<ApiUpstreamException>(),
    };
    const codes = {
      401: 'auth_error',
      403: 'forbidden',
      404: 'not_found',
      409: 'conflict',
      502: 'upstream_error',
    };
    for (final MapEntry(key: status, value: type) in cases.entries) {
      test('$status ${codes[status]}', () async {
        final e = await failWith(status, {
          'error': {
            'code': codes[status],
            'message': 'Something specific.',
            'details': {'why': 'because'},
          },
        });
        expect(e, type);
        expect(e.code, codes[status]);
        expect(e.message, 'Something specific.');
        expect(e.details, {'why': 'because'});
      });
    }

    test('null details', () async {
      final e = await failWith(404, {
        'error': {
          'code': 'not_found',
          'message': 'Goal not found.',
          'details': null,
        },
      });
      expect(e.message, 'Goal not found.');
      expect(e.details, isNull);
    });
  });

  group("django-ninja's own bodies", () {
    test('422 request validation names the first bad field', () async {
      final detail = [
        {
          'type': 'missing',
          'loc': ['body', 'payload', 'name'],
          'msg': 'Field required',
        },
        {
          'type': 'decimal_parsing',
          'loc': ['body', 'payload', 'balance'],
          'msg': 'Input should be a valid decimal',
        },
      ];
      final e = await failWith(422, {'detail': detail});
      expect(e, isA<ApiValidationException>());
      expect(e.message, 'name: Field required');
      expect(e.details, detail);
    });

    test('422 without a field location', () async {
      final e = await failWith(422, {
        'detail': [
          {
            'type': 'json_invalid',
            'loc': ['body', 'payload'],
            'msg': 'Invalid JSON',
          },
        ],
      });
      expect(e.message, 'Invalid JSON');
    });

    test('422 with an empty or odd detail list', () async {
      expect((await failWith(422, {'detail': []})).message, 'Invalid request');
      expect(
        (await failWith(422, {
          'detail': ['?'],
        })).message,
        'Invalid request',
      );
    });

    test('400 unparseable body', () async {
      final e = await failWith(400, {'detail': 'Cannot parse request body'});
      expect(e, isA<ApiValidationException>());
      expect(e.message, 'Cannot parse request body');
    });

    test('401 missing credentials', () async {
      // Not the token-refresh path: there's no refresh token to try.
      final e = await failWith(401, {'detail': 'Unauthorized'});
      expect(e, isA<ApiAuthException>());
      expect(e.message, 'Unauthorized');
    });
  });
}
