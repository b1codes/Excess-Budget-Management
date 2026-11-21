// Whole-app tests: BudgetApp from main.dart, wired by bootstrap() to a fake
// backend. They cover the startup auth check, the auth redirects and session
// expiry end to end through the real router.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/core/router.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/features/auth/presentation/screens/signup_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';
import 'package:frontend/main.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/api_fixtures.dart';
import 'helpers/fake_api.dart';
import 'helpers/mocks.dart' show kProfile;

void main() {
  late ScriptedAdapter adapter;
  late MockTokenStore tokens;
  late bool signedIn;

  setUp(() {
    signedIn = false;
    adapter = ScriptedAdapter()
      ..fallback = (options) {
        final path = options.path;
        if (path == '/auth/me') {
          return signedIn ? (200, userJson()) : (401, {'detail': 'no'});
        }
        if (!signedIn) return (401, {'detail': 'expired'});
        if (path == '/allocations/summary') {
          return (200, {'totalSavings': 0, 'totalPurchases': 0});
        }
        return (200, <dynamic>[]);
      };
    tokens = MockTokenStore();
    when(() => tokens.readAccess()).thenAnswer((_) async => 'access');
    when(() => tokens.readRefresh()).thenAnswer((_) async => null);
    when(() => tokens.clear()).thenAnswer((_) async {});
    when(() => tokens.write(any(), any())).thenAnswer((_) async {});
  });

  Future<({BudgetApp app, AuthBloc authBloc})> pumpApp(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final deps = bootstrap(dio: dio, tokenStore: tokens);
    final app = BudgetApp(apiClient: deps.apiClient, authBloc: deps.authBloc);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    addTearDown(() async {
      // Unmount so polling timers are cancelled before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await deps.authBloc.close();
    });
    return (app: app, authBloc: deps.authBloc);
  }

  testWidgets('shows the login screen when there is no session', (
    tester,
  ) async {
    final (:app, :authBloc) = await pumpApp(tester);

    expect(authBloc.state, isA<AuthUnauthenticated>());
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(app.apiClient.tokenStore, same(tokens));
  });

  testWidgets('goes to the dashboard when the session is valid', (
    tester,
  ) async {
    signedIn = true;
    final (app: _, :authBloc) = await pumpApp(tester);

    expect(authBloc.state, isA<AuthAuthenticated>());
    expect(find.byType(OverviewTab), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  // Regression: the router didn't listen to AuthBloc, so signing out left
  // the user where they were.
  testWidgets('signing out returns to the login screen', (tester) async {
    signedIn = true;
    final (app: _, :authBloc) = await pumpApp(tester);
    expect(find.byType(OverviewTab), findsOneWidget);

    authBloc.add(AuthLogoutRequested());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    verify(() => tokens.clear()).called(greaterThanOrEqualTo(1));
  });

  // Regression: main.dart's onUnauthenticated was a no-op, so an expired
  // session left the app "signed in" with every request failing.
  testWidgets('an expired session signs the user out', (tester) async {
    signedIn = true;
    final (app: app, :authBloc) = await pumpApp(tester);
    expect(find.byType(OverviewTab), findsOneWidget);

    signedIn = false; // access token now rejected, and there's no refresh
    // Don't await the request directly: inside testWidgets it only completes
    // as the fake clock is pumped.
    Object? error;
    app.apiClient.get<dynamic>('/accounts').catchError((Object e) {
      error = e;
      return Response<dynamic>(requestOptions: RequestOptions());
    });
    await tester.pumpAndSettle();

    expect(error, isA<ApiAuthException>());
    expect(authBloc.state, isA<AuthUnauthenticated>());
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  group('authRedirect', () {
    const authed = AuthAuthenticated(kProfile);

    test('sends signed-out users to /login from any app page', () {
      for (final s in [AuthInitial(), AuthLoading(), AuthUnauthenticated()]) {
        expect(authRedirect(s, Uri.parse('/')), '/login');
        expect(authRedirect(s, Uri.parse('/goals/overtime')), '/login');
      }
    });

    test('lets signed-out users stay on /login and /signup', () {
      expect(authRedirect(AuthUnauthenticated(), Uri.parse('/login')), isNull);
      expect(
        authRedirect(AuthUnauthenticated(), Uri.parse('/signup?ref=x')),
        isNull,
      );
    });

    test('bounces signed-in users off /login and /signup', () {
      expect(authRedirect(authed, Uri.parse('/login')), '/');
      expect(authRedirect(authed, Uri.parse('/signup')), '/');
    });

    test('leaves signed-in users on app pages', () {
      expect(authRedirect(authed, Uri.parse('/accounts')), isNull);
      expect(authRedirect(authed, Uri.parse('/profile')), isNull);
    });
  });

  testWidgets('the signup link opens the signup screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
