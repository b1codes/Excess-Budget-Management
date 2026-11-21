import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/income/bloc/overtime_bloc.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:frontend/features/income/presentation/screens/overtime_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late MockIncomeRepository income;
  late MockGoalRepository goals;
  // Created inside each testWidgets body (via pumpScreen) so its async work
  // runs in the test's fake-async zone.
  late OvertimeBloc bloc;

  setUpAll(() => registerFallbackValue(overtimeSettings()));

  void projectWith(FutureOr<OvertimeProjection> Function() answer) {
    when(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: any(named: 'overtimeHoursPerWeek'),
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).thenAnswer((_) async => answer());
  }

  setUp(() {
    income = MockIncomeRepository();
    goals = MockGoalRepository();
    when(
      () => income.getOvertimeSettings(),
    ).thenAnswer((_) async => overtimeSettings());
    when(() => goals.getGoals()).thenAnswer(
      (_) async => [
        goal(
          subGoals: [
            subGoal(),
            subGoal(id: 'sub-2', name: 'Brakes'),
          ],
        ),
        goal(id: 'goal-2', name: 'Car', current: 0, target: 8000),
      ],
    );
    projectWith(overtimeProjection);
  });

  Widget screen() {
    bloc = OvertimeBloc(incomeRepository: income, goalRepository: goals)
      ..add(FetchOvertimeData());
    addTearDown(bloc.close);
    return BlocProvider.value(value: bloc, child: const OvertimeScreen());
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1200, 1400),
  }) async {
    await pumpHarness(tester, screen(), size: size, wrapInScaffold: false);
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while loading', (tester) async {
    final pending = Completer<OvertimeSettings>();
    when(() => income.getOvertimeSettings()).thenAnswer((_) => pending.future);
    await pumpHarness(tester, screen(), wrapInScaffold: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(overtimeSettings());
    await tester.pumpAndSettle();
    expect(find.text('Overtime Accelerator'), findsOneWidget);
  });

  testWidgets('fills the form from saved settings and shows the projection', (
    tester,
  ) async {
    await pump(tester);

    expect(find.widgetWithText(TextFormField, '30.00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1.50'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '0.25'), findsOneWidget);
    expect(find.text(r'$33.75 / hr'), findsOneWidget);
    expect(find.text(r'+$168.75'), findsOneWidget);
    expect(find.text(r'+$731.25'), findsOneWidget);
    expect(find.text('Emergency fund'), findsWidgets);
    expect(find.text(r'$3750.00 remaining'), findsOneWidget);
    expect(find.text('11.5 mos saved'), findsOneWidget);
    expect(find.text('Standard Savings Path'), findsOneWidget);
    expect(find.text('Overtime Accelerated Path'), findsOneWidget);
    expect(find.text('Psychological Goal Target'), findsOneWidget);
  });

  testWidgets('lays the form and projection out in a column when compact', (
    tester,
  ) async {
    await pump(tester, size: const Size(400, 2400));
    final form = tester.getTopLeft(find.text('Earnings Profile'));
    final rate = tester.getTopLeft(find.text('Net Overtime Hourly Rate'));
    expect(rate.dy, greaterThan(form.dy));
  });

  testWidgets('editing a rate field re-projects with the new settings', (
    tester,
  ) async {
    await pump(tester);
    clearInteractions(income);

    await tester.enterText(find.widgetWithText(TextFormField, '30.00'), '45');
    await tester.pumpAndSettle();

    expect(bloc.state.settings!.hourlyBaseRate, 45);
    verify(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: any(named: 'overtimeHoursPerWeek'),
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).called(1);
  });

  testWidgets('blank or invalid fields fall back to defaults', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '1.50'), '');
    await tester.enterText(find.widgetWithText(TextFormField, '0.25'), 'x');
    await tester.pumpAndSettle();
    expect(bloc.state.settings!.overtimeMultiplier, 1.5);
    expect(bloc.state.settings!.estimatedTaxRate, 0.25);
  });

  testWidgets('the contribution field updates the standard contribution', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '0.00'), '200');
    await tester.pumpAndSettle();
    expect(bloc.state.standardContribution, 200);
  });

  testWidgets('the slider sets weekly overtime hours', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(bloc.state.overtimeHoursPerWeek, closeTo(20, 0.5));
    expect(find.textContaining('hrs / week'), findsOneWidget);
  });

  testWidgets('picking a goal and a subgoal targets the projection', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Entire Goal (Aggregate)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brakes').last);
    await tester.pumpAndSettle();
    expect(bloc.state.selectedSubgoalId, 'sub-2');
    expect(find.text('Emergency fund → Brakes'), findsOneWidget);

    await tester.tap(find.text('Emergency fund').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Car').last);
    await tester.pumpAndSettle();
    expect(bloc.state.selectedGoalId, 'goal-2');
    expect(bloc.state.selectedSubgoalId, isNull);
    expect(find.text('Entire Goal (Aggregate)'), findsNothing);
  });

  testWidgets('shows a hint when there is no projection yet', (tester) async {
    projectWith(() => throw const ApiServerException('down'));
    await pump(tester);
    expect(
      find.text('Adjust settings or select a goal to see projections.'),
      findsOneWidget,
    );
    expect(find.textContaining('down'), findsOneWidget);
  });

  testWidgets('shows "Fully Funded" and a timeline hint for a funded goal', (
    tester,
  ) async {
    when(() => goals.getGoals()).thenAnswer((_) async => [goal(current: 5000)]);
    projectWith(
      () => OvertimeProjection(
        netHourlyRate: 1,
        weeklyOvertimeNetIncome: 0,
        monthlyOvertimeNetIncome: 0,
      ),
    );
    await pump(tester);
    expect(find.text('Fully Funded'), findsOneWidget);
    expect(
      find.text('Enter hours or standard contribution to estimate timeline.'),
      findsOneWidget,
    );
    expect(find.textContaining('mos saved'), findsNothing);
  });

  testWidgets('without goals, only the earnings impact is shown', (
    tester,
  ) async {
    when(() => goals.getGoals()).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.text('Overtime Earnings Impact'), findsOneWidget);
    expect(find.text('Time to Complete'), findsNothing);
  });

  testWidgets('saving confirms only after the save succeeds', (tester) async {
    final save = Completer<OvertimeSettings>();
    when(
      () => income.updateOvertimeSettings(any()),
    ).thenAnswer((_) => save.future);
    await pump(tester);

    await tester.tap(find.text('Save Settings'));
    await tester.pump();
    expect(find.text('Settings saved successfully.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    save.complete(overtimeSettings());
    await tester.pumpAndSettle();
    expect(find.text('Settings saved successfully.'), findsOneWidget);
  });

  // Regression: the confirmation was shown as soon as Save was tapped, even
  // when the save then failed.
  testWidgets('a failed save shows the error, not a confirmation', (
    tester,
  ) async {
    when(
      () => income.updateOvertimeSettings(any()),
    ).thenThrow(const ApiValidationException('tax rate must be 0..1'));
    await pump(tester);

    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings saved successfully.'), findsNothing);
    expect(find.byKey(const ValueKey('error_message')), findsOneWidget);
    expect(find.textContaining('tax rate must be 0..1'), findsOneWidget);
  });
}
