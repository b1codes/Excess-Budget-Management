import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/auth/presentation/screens/profile_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/api_fixtures.dart';
import '../../../../helpers/fake_api.dart';
import '../../../../helpers/widget_harness.dart';

const _picker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  late FakeApi api;
  late MockAuthBloc auth;

  setUpAll(() => registerFallbackValue(AuthLogoutRequested()));

  setUp(() {
    api = FakeApi(accessToken: 't')
      ..route('GET /auth/me', userJson(defaultSavingsRatio: 0.8))
      ..route('PATCH /auth/me', userJson());
    auth = MockAuthBloc();
    whenListen(
      auth,
      const Stream<AuthState>.empty(),
      initialState: AuthUnauthenticated(),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_picker, null);
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpHarness(
      tester,
      const ProfileScreen(),
      client: api.client,
      blocs: [BlocProvider<AuthBloc>.value(value: auth)],
      size: const Size(800, 1400),
      wrapInScaffold: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads and shows the profile', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(TextFormField, 'Test User'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'user@example.com'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  // Regression: percentages were truncated, so a 0.8 ratio showed
  // "19% Purchases" because 100 * (1 - 0.8) is 19.999...
  testWidgets('shows the savings split as whole, rounded percentages', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('20% Purchases / 80% Savings'), findsOneWidget);
  });

  testWidgets('shows an error when the profile fails to load', (tester) async {
    api.route('GET /auth/me', {'detail': 'down'}, status: 500);
    await pump(tester);
    expect(find.textContaining('Error loading profile'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpHarness(
      tester,
      const ProfileScreen(),
      client: api.client,
      blocs: [BlocProvider<AuthBloc>.value(value: auth)],
      wrapInScaffold: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('saves the name on submit', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Test User'),
      '  Ada Lovelace ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      api.calls('PATCH /auth/me').single.jsonBody['full_name'],
      'Ada Lovelace',
    );
    expect(find.text('Profile updated'), findsOneWidget);
  });

  testWidgets('reports a failed name update', (tester) async {
    await pump(tester);
    api.route('PATCH /auth/me', {'detail': 'nope'}, status: 422);
    await tester.showKeyboard(find.widgetWithText(TextFormField, 'Test User'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('Error updating profile'), findsOneWidget);
  });

  testWidgets('saves the savings ratio when the slider is released', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();

    expect(api.calls('PATCH /auth/me').single.jsonBody, {
      'default_savings_ratio': 0.5,
    });
    expect(find.text('50% Purchases / 50% Savings'), findsOneWidget);
    expect(find.text('Settings saved'), findsOneWidget);
  });

  testWidgets('reports a failed ratio save', (tester) async {
    api.route('PATCH /auth/me', {'detail': 'nope'}, status: 500);
    await pump(tester);
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error saving'), findsOneWidget);
  });

  testWidgets('logout asks the auth bloc to sign out', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Logout'));
    verify(() => auth.add(any(that: isA<AuthLogoutRequested>()))).called(1);
  });

  group('avatar', () {
    void pickerReturns(String? path) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_picker, (call) async => path);
    }

    testWidgets('does nothing when picking is cancelled', (tester) async {
      pickerReturns(null);
      await pump(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(api.calls('PATCH /auth/me'), isEmpty);
    });

    // Upload isn't implemented on the backend yet, so the repository throws
    // and the screen reports it.
    testWidgets('reports that upload is unavailable', (tester) async {
      pickerReturns('/tmp/avatar.png');
      await pump(tester);
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error uploading avatar'), findsOneWidget);
      expect(api.calls('PATCH /auth/me'), isEmpty);
    });
  });

  testWidgets('shows the avatar image when the profile has one', (
    tester,
  ) async {
    api.route('GET /auth/me', userJson(avatarUrl: 'http://example.com/a.png'));
    await pump(tester);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundImage, isA<NetworkImage>());
    // Network images fail in tests; that's expected here.
    tester.takeException();
  });

  // The load handler must not call setState once the screen is gone.
  testWidgets('leaving before the profile loads does not throw', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      const ProfileScreen(),
      client: api.client,
      blocs: [BlocProvider<AuthBloc>.value(value: auth)],
      wrapInScaffold: false,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
