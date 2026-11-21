import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthService auth;

  setUp(() => auth = MockAuthService());

  AuthBloc build() => AuthBloc(authService: auth);

  test('starts in AuthInitial', () {
    expect(build().state, isA<AuthInitial>());
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits AuthAuthenticated when a session exists',
      setUp: () =>
          when(() => auth.currentUser()).thenAnswer((_) async => kProfile),
      build: build,
      act: (b) => b.add(AuthCheckRequested()),
      expect: () => [const AuthAuthenticated(kProfile)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthUnauthenticated when there is no session',
      setUp: () => when(() => auth.currentUser()).thenAnswer((_) async => null),
      build: build,
      act: (b) => b.add(AuthCheckRequested()),
      expect: () => [AuthUnauthenticated()],
    );

    // Regression: a network error used to escape the handler and leave the
    // bloc in AuthInitial.
    blocTest<AuthBloc, AuthState>(
      'emits AuthUnauthenticated when the check fails, e.g. offline',
      setUp: () => when(
        () => auth.currentUser(),
      ).thenThrow(const ApiNetworkException('offline')),
      build: build,
      act: (b) => b.add(AuthCheckRequested()),
      expect: () => [AuthUnauthenticated()],
    );
  });

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading, then authenticated',
      setUp: () => when(
        () => auth.signIn('a@b.com', 'pw'),
      ).thenAnswer((_) async => kProfile),
      build: build,
      act: (b) => b.add(const AuthLoginRequested('a@b.com', 'pw')),
      expect: () => [AuthLoading(), const AuthAuthenticated(kProfile)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits the server message on failure',
      setUp: () => when(
        () => auth.signIn(any(), any()),
      ).thenThrow(const ApiAuthException('Invalid credentials')),
      build: build,
      act: (b) => b.add(const AuthLoginRequested('a@b.com', 'bad')),
      expect: () => [AuthLoading(), const AuthError('Invalid credentials')],
    );
  });

  group('AuthSignupRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading, then authenticated',
      setUp: () => when(
        () => auth.signUp('new@b.com', 'longpassword'),
      ).thenAnswer((_) async => kProfile),
      build: build,
      act: (b) => b.add(const AuthSignupRequested('new@b.com', 'longpassword')),
      expect: () => [AuthLoading(), const AuthAuthenticated(kProfile)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits the server message on a conflict',
      setUp: () => when(
        () => auth.signUp(any(), any()),
      ).thenThrow(const ApiConflictException('Email already registered')),
      build: build,
      act: (b) => b.add(const AuthSignupRequested('dup@b.com', 'x')),
      expect: () => [
        AuthLoading(),
        const AuthError('Email already registered'),
      ],
    );
  });

  group('AuthAuth0LoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading, then authenticated',
      setUp: () => when(
        () => auth.signInWithAuth0('id-token'),
      ).thenAnswer((_) async => kProfile),
      build: build,
      act: (b) => b.add(const AuthAuth0LoginRequested('id-token')),
      expect: () => [AuthLoading(), const AuthAuthenticated(kProfile)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits the server message on failure',
      setUp: () => when(
        () => auth.signInWithAuth0(any()),
      ).thenThrow(const ApiAuthException('Invalid Auth0 token')),
      build: build,
      act: (b) => b.add(const AuthAuth0LoginRequested('bad')),
      expect: () => [AuthLoading(), const AuthError('Invalid Auth0 token')],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'AuthLogoutRequested clears the session and emits unauthenticated',
    setUp: () => when(() => auth.signOut()).thenAnswer((_) async {}),
    build: build,
    seed: () => const AuthAuthenticated(kProfile),
    act: (b) => b.add(AuthLogoutRequested()),
    expect: () => [AuthLoading(), AuthUnauthenticated()],
    verify: (_) => verify(() => auth.signOut()).called(1),
  );

  test('event and state equality', () {
    expect(
      const AuthLoginRequested('a', 'b'),
      const AuthLoginRequested('a', 'b'),
    );
    expect(const AuthLoginRequested('a', 'b').props, ['a', 'b']);
    expect(const AuthSignupRequested('a', 'b').props, ['a', 'b']);
    expect(const AuthAuth0LoginRequested('t').props, ['t']);
    expect(AuthCheckRequested().props, isEmpty);
    expect(const AuthError('m').props, ['m']);
    expect(const AuthAuthenticated(kProfile).props, ['42']);
  });
}
