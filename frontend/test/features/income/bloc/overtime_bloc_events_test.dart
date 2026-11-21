import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/income/bloc/overtime_bloc.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockIncomeRepository income;
  late MockGoalRepository goals;

  setUpAll(() => registerFallbackValue(overtimeSettings()));

  setUp(() {
    income = MockIncomeRepository();
    goals = MockGoalRepository();
    when(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: any(named: 'overtimeHoursPerWeek'),
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).thenAnswer((_) async => overtimeProjection());
  });

  OvertimeBloc build() =>
      OvertimeBloc(incomeRepository: income, goalRepository: goals);

  OvertimeState ready() => OvertimeState(
    settings: overtimeSettings(),
    goals: [goal()],
    selectedGoalId: 'goal-1',
  );

  group('FetchOvertimeData', () {
    blocTest<OvertimeBloc, OvertimeState>(
      'pre-selects the first goal when every goal is complete',
      setUp: () {
        when(
          () => income.getOvertimeSettings(),
        ).thenAnswer((_) async => overtimeSettings());
        when(() => goals.getGoals()).thenAnswer(
          (_) async => [
            goal(id: 'a', current: 5000),
            goal(id: 'b', current: 5000),
          ],
        );
      },
      build: build,
      act: (b) => b.add(FetchOvertimeData()),
      verify: (b) => expect(b.state.selectedGoalId, 'a'),
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'pre-selects the first unfinished goal',
      setUp: () {
        when(
          () => income.getOvertimeSettings(),
        ).thenAnswer((_) async => overtimeSettings());
        when(() => goals.getGoals()).thenAnswer(
          (_) async => [goal(id: 'done', current: 5000), goal(id: 'open')],
        );
      },
      build: build,
      act: (b) => b.add(FetchOvertimeData()),
      verify: (b) => expect(b.state.selectedGoalId, 'open'),
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'selects nothing without goals and still projects',
      setUp: () {
        when(
          () => income.getOvertimeSettings(),
        ).thenAnswer((_) async => overtimeSettings());
        when(() => goals.getGoals()).thenAnswer((_) async => []);
      },
      build: build,
      act: (b) => b.add(FetchOvertimeData()),
      verify: (b) {
        expect(b.state.selectedGoalId, isNull);
        expect(b.state.projection, isNotNull);
      },
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'reports a load error and clears it on the next attempt',
      setUp: () {
        var calls = 0;
        when(() => income.getOvertimeSettings()).thenAnswer((_) async {
          if (calls++ == 0) throw const ApiNetworkException('offline');
          return overtimeSettings();
        });
        when(() => goals.getGoals()).thenAnswer((_) async => []);
      },
      build: build,
      act: (b) async {
        b.add(FetchOvertimeData());
        await Future<void>.delayed(Duration.zero);
        expect(b.state.errorMessage, contains('offline'));
        expect(b.state.isLoading, isFalse);
        b.add(FetchOvertimeData());
      },
      verify: (b) {
        expect(b.state.errorMessage, isNull);
        expect(b.state.settings, isNotNull);
      },
    );
  });

  group('field updates', () {
    blocTest<OvertimeBloc, OvertimeState>(
      'settings edits are ignored until settings have loaded',
      build: build,
      act: (b) => b
        ..add(UpdateOvertimeSettingsField(hourlyBaseRate: 50))
        ..add(SaveOvertimeSettings()),
      expect: () => <OvertimeState>[],
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'a settings edit updates the settings and re-projects',
      build: build,
      seed: ready,
      act: (b) => b.add(
        UpdateOvertimeSettingsField(
          hourlyBaseRate: 50,
          overtimeMultiplier: 2,
          estimatedTaxRate: 0.3,
        ),
      ),
      verify: (b) {
        expect(b.state.settings!.hourlyBaseRate, 50);
        expect(b.state.settings!.overtimeMultiplier, 2);
        expect(b.state.settings!.estimatedTaxRate, 0.3);
        verify(
          () => income.getOvertimeProjection(
            overtimeHoursPerWeek: 0,
            standardContribution: 0,
            goalId: 'goal-1',
          ),
        ).called(1);
      },
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'a contribution change re-projects with the new contribution',
      build: build,
      seed: ready,
      act: (b) => b.add(UpdateStandardContribution(250)),
      verify: (b) {
        expect(b.state.standardContribution, 250);
        verify(
          () => income.getOvertimeProjection(
            overtimeHoursPerWeek: 0,
            standardContribution: 250,
            goalId: 'goal-1',
          ),
        ).called(1);
      },
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'selecting a subgoal re-projects for it, and can clear the selection',
      build: build,
      seed: ready,
      act: (b) async {
        b.add(SelectGoalOrSubgoal(goalId: 'goal-1', subgoalId: 'sub-1'));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.selectedSubgoalId, 'sub-1');
        b.add(SelectGoalOrSubgoal());
      },
      verify: (b) {
        expect(b.state.selectedGoalId, isNull);
        expect(b.state.selectedSubgoalId, isNull);
        verify(
          () => income.getOvertimeProjection(
            overtimeHoursPerWeek: 0,
            standardContribution: 0,
            goalId: 'goal-1',
            subgoalId: 'sub-1',
          ),
        ).called(1);
      },
    );
  });

  group('SaveOvertimeSettings', () {
    blocTest<OvertimeBloc, OvertimeState>(
      'saves, adopts the server\'s settings and re-projects',
      setUp: () => when(
        () => income.updateOvertimeSettings(any()),
      ).thenAnswer((_) async => overtimeSettings(rate: 99)),
      build: build,
      seed: ready,
      act: (b) => b.add(SaveOvertimeSettings()),
      expect: () => [
        isA<OvertimeState>().having((s) => s.isSaving, 'saving', isTrue),
        isA<OvertimeState>()
            .having((s) => s.isSaving, 'saving', isFalse)
            .having((s) => s.settings!.hourlyBaseRate, 'rate', 99),
        isA<OvertimeState>().having((s) => s.isCalculating, 'calc', isTrue),
        isA<OvertimeState>().having((s) => s.isCalculating, 'calc', isFalse),
      ],
    );

    blocTest<OvertimeBloc, OvertimeState>(
      'reports a failed save',
      setUp: () => when(
        () => income.updateOvertimeSettings(any()),
      ).thenThrow(const ApiValidationException('tax rate must be 0..1')),
      build: build,
      seed: ready,
      act: (b) => b.add(SaveOvertimeSettings()),
      verify: (b) {
        expect(b.state.isSaving, isFalse);
        expect(b.state.errorMessage, contains('tax rate'));
      },
    );
  });

  blocTest<OvertimeBloc, OvertimeState>(
    'reports a failed projection',
    setUp: () => when(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: any(named: 'overtimeHoursPerWeek'),
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).thenThrow(const ApiServerException('down')),
    build: build,
    seed: ready,
    act: (b) => b.add(UpdateOvertimeHours(5)),
    verify: (b) {
      expect(b.state.isCalculating, isFalse);
      expect(b.state.errorMessage, contains('down'));
    },
  );

  // Regression: projection requests ran concurrently and each one wrote its
  // result, so a slow response for an old slider value could replace the
  // projection for the current value.
  test('a stale projection response never replaces a newer one', () async {
    final slow = Completer<OvertimeProjection>();
    final stale = overtimeProjection(monthsSaved: 1);
    final fresh = overtimeProjection(monthsSaved: 2);
    when(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: 5,
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).thenAnswer((_) => slow.future);
    when(
      () => income.getOvertimeProjection(
        overtimeHoursPerWeek: 10,
        standardContribution: any(named: 'standardContribution'),
        goalId: any(named: 'goalId'),
        subgoalId: any(named: 'subgoalId'),
      ),
    ).thenAnswer((_) async => fresh);

    final bloc = build()..emit(ready());
    bloc.add(UpdateOvertimeHours(5));
    await Future<void>.delayed(Duration.zero);
    bloc.add(UpdateOvertimeHours(10));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.projection, same(fresh));

    slow.complete(stale);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.projection, same(fresh));
    expect(bloc.state.overtimeHoursPerWeek, 10);
    expect(bloc.state.isCalculating, isFalse);
    await bloc.close();
  });

  test('copyWith keeps or replaces each field', () {
    final s = OvertimeState(
      settings: overtimeSettings(),
      selectedGoalId: 'g',
      selectedSubgoalId: 's',
      errorMessage: 'e',
      projection: overtimeProjection(),
    );
    final same = s.copyWith();
    expect(same.selectedGoalId, 'g');
    expect(same.selectedSubgoalId, 's');
    expect(same.errorMessage, 'e');
    expect(same.projection, s.projection);
    final changed = s.copyWith(
      isLoading: true,
      isSaving: true,
      isCalculating: true,
      goals: [goal()],
      overtimeHoursPerWeek: 3,
      standardContribution: 4,
      settings: OvertimeSettings(
        hourlyBaseRate: 1,
        overtimeMultiplier: 1,
        estimatedTaxRate: 0,
      ),
    );
    expect(
      changed.isLoading && changed.isSaving && changed.isCalculating,
      isTrue,
    );
    expect(changed.goals, hasLength(1));
    expect(changed.overtimeHoursPerWeek, 3);
    expect(changed.standardContribution, 4);
    expect(changed.settings!.hourlyBaseRate, 1);
  });
}
