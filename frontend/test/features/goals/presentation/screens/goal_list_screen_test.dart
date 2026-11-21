import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/llc_theme.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:frontend/features/goals/presentation/screens/goal_list_screen.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_detail_view.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/api_fixtures.dart';
import '../../../../helpers/fake_api.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late FakeApi api;
  late MockAccountBloc accounts;

  setUpAll(() => registerFallbackValue(LoadAccounts()));

  setUp(() {
    api = FakeApi()
      ..route('GET /goals', [
        goalJson(),
        goalJson(
          id: 'goal-2',
          name: 'New car',
          currentAmount: '8000.00',
          targetAmount: '8000.00',
          accountIds: ['acc-1'],
        ),
      ])
      ..route('POST /goals', goalJson(id: 'goal-3'), status: 201)
      ..route('DELETE /goals/goal-1', null, status: 204);
    accounts = MockAccountBloc();
    whenListen(
      accounts,
      const Stream<AccountState>.empty(),
      initialState: AccountLoaded([
        account(),
        account(id: 'acc-2', name: 'Savings'),
      ]),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    setScreenSize(tester, size);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const GoalListScreen()),
        GoRoute(
          path: '/goals/overtime',
          builder: (_, _) => const Scaffold(body: Text('overtime page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<ApiClient>.value(
        value: api.client,
        child: BlocProvider<AccountBloc>.value(
          value: accounts,
          child: MaterialApp.router(
            theme: LLCTheme.dark(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists goals with progress and a sync badge', (tester) async {
    await pump(tester);
    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text(r'$1250.00 of $5000.00'), findsOneWidget);
    expect(find.text('New car'), findsOneWidget);
    expect(find.byTooltip('Synced with Account'), findsOneWidget);
    expect(find.text('Overtime Accelerator'), findsOneWidget);
  });

  testWidgets('shows an empty state', (tester) async {
    api.route('GET /goals', <dynamic>[]);
    await pump(tester);
    expect(find.text('No goals yet. Add one to start saving!'), findsOneWidget);
  });

  testWidgets('reports a load failure', (tester) async {
    api.route('GET /goals', {'detail': 'down'}, status: 500);
    await pump(tester);
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('the overtime card opens the overtime page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Overtime Accelerator'));
    await tester.pumpAndSettle();
    expect(find.text('overtime page'), findsOneWidget);
  });

  testWidgets('wide: selecting a goal shows its detail beside the list', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Emergency fund'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailView), findsOneWidget);
    expect(find.text('Overall Progress'), findsOneWidget);

    // Deleting from the detail clears the selection.
    await tester.tap(
      find.descendant(
        of: find.byType(GoalDetailView),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailView), findsNothing);
    expect(api.calls('DELETE /goals/goal-1'), hasLength(1));
  });

  group('compact', () {
    const phone = Size(400, 900);

    testWidgets('opens the goal on its own page and reloads on return', (
      tester,
    ) async {
      await pump(tester, size: phone);
      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      expect(find.byType(GoalDetailScreen), findsOneWidget);

      final loads = api.calls('GET /goals').length;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(api.calls('GET /goals').length, greaterThan(loads));
    });

    testWidgets('the app bar opens the overtime page', (tester) async {
      await pump(tester, size: phone);
      await tester.tap(find.byTooltip('Overtime Accelerator'));
      await tester.pumpAndSettle();
      expect(find.text('overtime page'), findsOneWidget);
    });

    // Regression: the card's delete button deleted the goal (and with it
    // its subgoals and allocations) on a single tap.
    testWidgets('deleting from a card asks first', (tester) async {
      await pump(tester, size: phone);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Delete Goal'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls('DELETE /goals/goal-1'), isEmpty);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(api.calls('DELETE /goals/goal-1'), hasLength(1));
    });

    testWidgets('reports a failed delete', (tester) async {
      api.route('DELETE /goals/goal-1', {'detail': 'down'}, status: 500);
      await pump(tester, size: phone);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not delete goal'), findsOneWidget);
    });
  });

  group('adding a goal', () {
    Future<void> openForm(WidgetTester tester) async {
      await pump(tester, size: const Size(1200, 1400));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(GoalFormSheet), findsOneWidget);
    }

    testWidgets('validates the name and amount', (tester) async {
      await openForm(tester);
      await tester.tap(find.text('Save Goal'));
      await tester.pumpAndSettle();
      expect(find.text('Goal Name is required'), findsOneWidget);
      expect(find.text('Amount is required'), findsOneWidget);
      expect(api.calls('POST /goals'), isEmpty);
    });

    testWidgets('creates a goal with every option', (tester) async {
      api.route('POST /goals/goal-3/accounts', {}, status: 201);
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal Name'),
        'Laptop',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target Amount'),
        '1800',
      );
      await tester.tap(find.text('Short Term'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long Term').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Purchase'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Savings'));
      await tester.pump();
      expect(
        find.textContaining('manual progress updates will be disabled'),
        findsOneWidget,
      );
      await tester.tap(find.text('Target Date (Optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Not set'), findsNothing);

      await tester.tap(find.text('Save Goal'));
      await tester.pumpAndSettle();

      final body = api.calls('POST /goals').single.jsonBody;
      expect(body['name'], 'Laptop');
      expect(body['target_amount'], '1800.00');
      expect(body['type'], 'long_term');
      expect(body['category'], 'purchase');
      expect(body['target_date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(api.calls('POST /goals/goal-3/accounts').single.jsonBody, {
        'account_id': 'acc-2',
      });
      expect(find.byType(GoalFormSheet), findsNothing);
    });

    testWidgets('unselecting an account drops it again', (tester) async {
      await openForm(tester);
      final chip = find.widgetWithText(FilterChip, 'Checking');
      await tester.tap(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(
        find.textContaining('manual progress updates will be disabled'),
        findsNothing,
      );
    });

    // Regression: the sheet closed without waiting for the request, and a
    // failure was silently dropped.
    testWidgets('reports a failed create', (tester) async {
      api.route('POST /goals', {'detail': 'down'}, status: 500);
      await openForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Goal Name'),
        'Laptop',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target Amount'),
        '1800',
      );
      await tester.tap(find.text('Save Goal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not add goal'), findsOneWidget);
    });
  });

  testWidgets('the form asks for accounts when they are not loaded', (
    tester,
  ) async {
    whenListen(
      accounts,
      const Stream<AccountState>.empty(),
      initialState: AccountInitial(),
    );
    await pumpHarness(
      tester,
      GoalFormSheet(
        goal: goal(targetDate: DateTime(2030)),
        onSave: (_, _, _, _, _, _) {},
      ),
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
    );
    expect(find.text('Edit Goal'), findsOneWidget);
    expect(find.text('2030-01-01'), findsOneWidget);
    expect(find.text('Auto-sync with Accounts (Optional)'), findsNothing);
    verify(() => accounts.add(any(that: isA<LoadAccounts>()))).called(1);
  });
}
