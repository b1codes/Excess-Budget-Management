import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late AuthTokenStore store;

  setUp(() {
    storage = _MockStorage();
    store = AuthTokenStore(storage: storage);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test('reads the access and refresh tokens from their own keys', () async {
    when(() => storage.read(key: 'access_token')).thenAnswer((_) async => 'a');
    when(() => storage.read(key: 'refresh_token')).thenAnswer((_) async => 'r');

    expect(await store.readAccess(), 'a');
    expect(await store.readRefresh(), 'r');
  });

  test('returns null when nothing is stored', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    expect(await store.readAccess(), isNull);
    expect(await store.readRefresh(), isNull);
  });

  test('write stores both tokens', () async {
    await store.write('new-a', 'new-r');
    verify(() => storage.write(key: 'access_token', value: 'new-a')).called(1);
    verify(() => storage.write(key: 'refresh_token', value: 'new-r')).called(1);
  });

  test('clear deletes both tokens', () async {
    await store.clear();
    verify(() => storage.delete(key: 'access_token')).called(1);
    verify(() => storage.delete(key: 'refresh_token')).called(1);
  });

  test('defaults to the platform secure storage', () {
    expect(AuthTokenStore(), isA<AuthTokenStore>());
  });
}
