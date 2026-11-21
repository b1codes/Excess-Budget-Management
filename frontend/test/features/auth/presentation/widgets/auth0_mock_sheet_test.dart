import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/auth/presentation/widgets/auth0_mock_sheet.dart';
import 'package:frontend/features/auth/presentation/widgets/login_form.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/widget_harness.dart';

/// Decodes the payload of an unsigned `header.payload.` token.
Map<String, dynamic> _payload(String token) {
  final parts = token.split('.');
  expect(parts, hasLength(3));
  expect(parts[2], isEmpty, reason: 'mock tokens are unsigned');
  final header = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
  );
  expect(header, {'alg': 'none', 'typ': 'JWT'});
  return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      )
      as Map<String, dynamic>;
}

void main() {
  group('Auth0MockSheet', () {
    late List<String> tokens;

    Future<void> open(WidgetTester tester) async {
      tokens = [];
      await pumpHarness(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => Auth0MockSheet(onLogin: tokens.add),
            ),
            child: const Text('open'),
          ),
        ),
        size: const Size(800, 1400),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('signs in with a social provider', (tester) async {
      await open(tester);
      expect(find.text('Sign in to Excess Budget'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.byType(Auth0MockSheet), findsNothing);
      final claims = _payload(tokens.single);
      expect(claims['email'], 'google-user@example.com');
      expect(claims['name'], 'Google User');
      expect(claims['iss'], 'https://${Constants.auth0Domain}/');
      expect(claims['aud'], Constants.auth0Audience);
      expect(claims['sub'], startsWith('auth0|mock_user_'));
    });

    testWidgets('Apple works the same way', (tester) async {
      await open(tester);
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();
      expect(_payload(tokens.single)['email'], 'apple-user@example.com');
    });

    testWidgets('the email flow requires an address', (tester) async {
      await open(tester);
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.tap(find.text('Log In'));
      await tester.pump();
      expect(find.text('Please enter an email address'), findsOneWidget);
      expect(tokens, isEmpty);
    });

    testWidgets('signs in with an email address', (tester) async {
      await open(tester);
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Email Address'),
        'ada@example.com',
      );
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      final claims = _payload(tokens.single);
      expect(claims['email'], 'ada@example.com');
      expect(claims['name'], 'ada');
    });

    testWidgets('toggles sign-up and returns to the other options', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Continue with Email'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Need an account?'));
      await tester.pumpAndSettle();
      expect(find.text('Create your Account'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      await tester.tap(find.text('Already have an account?'));
      await tester.pumpAndSettle();
      expect(find.text('Log In'), findsOneWidget);

      await tester.tap(find.text('Other login options'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('LoginForm', () {
    late MockAuthBloc auth;

    setUpAll(() => registerFallbackValue(AuthLogoutRequested()));

    setUp(() {
      auth = MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: AuthUnauthenticated(),
      );
    });

    Future<void> pumpForm(WidgetTester tester) => pumpHarness(
      tester,
      const SingleChildScrollView(child: LoginForm()),
      blocs: [BlocProvider<AuthBloc>.value(value: auth)],
      size: const Size(800, 1400),
    );

    testWidgets('requires both fields', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(find.text('Please fill in all fields'), findsOneWidget);
      verifyNever(() => auth.add(any()));
    });

    testWidgets('submits email and password', (tester) async {
      await pumpForm(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'a@b.com');
      await tester.enterText(fields.at(1), 'secret');
      await tester.tap(find.text('Login'));
      await tester.pump();
      verify(
        () => auth.add(const AuthLoginRequested('a@b.com', 'secret')),
      ).called(1);
    });

    testWidgets('forgot password explains it is not available yet', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.tap(find.text('Forgot Password?'));
      await tester.pump();
      expect(find.text('Forgot password not implemented yet'), findsOneWidget);
    });

    testWidgets('Auth0 sign-in sends the token to the bloc', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.text('Continue with Auth0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      final event =
          verify(() => auth.add(captureAny())).captured.single
              as AuthAuth0LoginRequested;
      expect(_payload(event.token)['email'], 'google-user@example.com');
    });

    testWidgets('disables input while signing in', (tester) async {
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: AuthLoading(),
      );
      await pumpForm(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((f) => f.enabled == false), isTrue);
    });
  });
}
