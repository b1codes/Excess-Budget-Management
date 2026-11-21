import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/auth/repositories/profile_repository.dart';
import 'package:image_picker/image_picker.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late ProfileRepository repo;

  setUp(() {
    api = FakeApi(accessToken: 'tok');
    repo = ProfileRepository(client: api.client);
  });

  test('getProfile GETs /auth/me', () async {
    api.enqueue(200, userJson(fullName: 'Ada'));

    final p = await repo.getProfile();

    expect(api.last.method, 'GET');
    expect(api.last.path, '/auth/me');
    expect(p.fullName, 'Ada');
    expect(p.defaultSavingsRatio, 0.5);
  });

  test('updateProfile PATCHes the editable fields only', () async {
    api.enqueue(200, userJson());

    await repo.updateProfile(
      const UserProfile(
        id: '42',
        email: 'ignored@example.com',
        fullName: 'Ada',
        avatarUrl: 'http://img',
        defaultSavingsRatio: 0.3,
      ),
    );

    expect(api.last.method, 'PATCH');
    expect(api.last.path, '/auth/me');
    expect(api.last.jsonBody, {
      'full_name': 'Ada',
      'avatar_url': 'http://img',
      'default_savings_ratio': 0.3,
    });
  });

  test('updateProfile surfaces a 422 as ApiValidationException', () async {
    api.enqueue(422, {'detail': 'ratio must be 0..1'});
    await expectLater(
      repo.updateProfile(const UserProfile(id: '1', defaultSavingsRatio: 2)),
      throwsA(isA<ApiValidationException>()),
    );
  });

  test('getDefaultSavingsRatio reads it from the profile', () async {
    api.enqueue(200, userJson(defaultSavingsRatio: 0.15));
    expect(await repo.getDefaultSavingsRatio(), 0.15);
    expect(api.last.path, '/auth/me');
  });

  test('updateDefaultSavingsRatio PATCHes only the ratio', () async {
    api.enqueue(200, userJson());
    await repo.updateDefaultSavingsRatio(0.25);
    expect(api.last.method, 'PATCH');
    expect(api.last.jsonBody, {'default_savings_ratio': 0.25});
  });

  test('uploadAvatar is not implemented yet and makes no request', () async {
    await expectLater(
      repo.uploadAvatar(XFile('avatar.png')),
      throwsA(isA<UnimplementedError>()),
    );
    expect(api.requests, isEmpty);
  });
}
