// Shared test harness for anything built on ApiClient.
//
// FakeApi wires a real ApiClient to a scripted HttpClientAdapter, so tests run
// the full Dio stack (interceptors, error mapping) without a network. Each
// request is recorded so tests can assert on method, path, query and body.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStore extends Mock implements AuthTokenStore {}

/// A request captured by [ScriptedAdapter].
class RecordedRequest {
  RecordedRequest(this.options);
  final RequestOptions options;

  String get method => options.method;
  String get path => options.path;
  Map<String, dynamic> get query => options.queryParameters;
  Object? get body => options.data;
  Map<String, dynamic> get jsonBody => options.data as Map<String, dynamic>;
}

/// Returns queued responses in order and records every request.
///
/// A queued [DioExceptionType] simulates a transport failure (no response).
class ScriptedAdapter implements HttpClientAdapter {
  final _queue = <Object>[];
  final requests = <RecordedRequest>[];

  /// Answers requests once the queue is empty, for tests (such as whole-app
  /// tests) that can't predict the order of requests. Returns
  /// `(status, body)`.
  (int, Object?) Function(RequestOptions options)? fallback;

  void enqueue(int status, [Object? body]) {
    _queue.add((status, body));
  }

  void enqueueNetworkError([
    DioExceptionType type = DioExceptionType.connectionError,
  ]) {
    _queue.add(type);
  }

  bool get isDrained => _queue.isEmpty;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options));
    final Object next;
    if (_queue.isNotEmpty) {
      next = _queue.removeAt(0);
    } else if (fallback != null) {
      next = fallback!(options);
    } else {
      throw StateError(
        'No queued response for ${options.method} ${options.path}',
      );
    }
    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next, message: 'boom');
    }
    final (status, body) = next as (int, Object?);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A real [ApiClient] backed by a [ScriptedAdapter] and a mocked token store.
class FakeApi {
  FakeApi({String? accessToken}) {
    when(() => tokenStore.readAccess()).thenAnswer((_) async => accessToken);
    when(() => tokenStore.readRefresh()).thenAnswer((_) async => null);
    when(() => tokenStore.write(any(), any())).thenAnswer((_) async {});
    when(() => tokenStore.clear()).thenAnswer((_) async {});

    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    client = ApiClient(
      dio: dio,
      tokenStore: tokenStore,
      onUnauthenticated: () async => unauthenticatedCalls++,
    );
  }

  final adapter = ScriptedAdapter();
  final tokenStore = MockTokenStore();
  late final ApiClient client;
  int unauthenticatedCalls = 0;

  void enqueue(int status, [Object? body]) => adapter.enqueue(status, body);
  List<RecordedRequest> get requests => adapter.requests;
  RecordedRequest get last => adapter.requests.last;
}
