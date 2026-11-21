import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late IncomeRepository repo;

  setUp(() {
    api = FakeApi();
    repo = IncomeRepository(client: api.client);
  });

  group('getIncome', () {
    test('GETs /income/extra and parses each entry', () async {
      api.enqueue(200, [extraIncomeJson(), extraIncomeJson(id: 'inc-2')]);

      final income = await repo.getIncome();

      expect(api.last.method, 'GET');
      expect(api.last.path, '/income/extra');
      expect(income.map((i) => i.id), ['inc-1', 'inc-2']);
      expect(income.first.amount, 250.0);
    });

    test('returns an empty list for an empty array', () async {
      api.enqueue(200, <dynamic>[]);
      expect(await repo.getIncome(), isEmpty);
    });
  });

  test('deleteIncome DELETEs /income/extra/:id', () async {
    api.enqueue(204);
    await repo.deleteIncome('inc-3');
    expect(api.last.method, 'DELETE');
    expect(api.last.path, '/income/extra/inc-3');
  });

  group('bulkInsertExtraIncome', () {
    test('POSTs one entry at a time without user_id', () async {
      api.enqueue(201, extraIncomeJson(id: 'a'));
      api.enqueue(201, extraIncomeJson(id: 'b'));

      await repo.bulkInsertExtraIncome([
        {'user_id': 'u', 'amount': '10.00', 'date_received': '2026-01-01'},
        {'amount': '20.00', 'date_received': '2026-01-02'},
      ]);

      expect(api.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /income/extra',
        'POST /income/extra',
      ]);
      expect(api.requests[0].jsonBody, {
        'amount': '10.00',
        'date_received': '2026-01-01',
      });
      expect(api.requests[1].jsonBody['amount'], '20.00');
    });

    test('stops at the first failure', () async {
      api.enqueue(500, {'detail': 'down'});
      await expectLater(
        repo.bulkInsertExtraIncome([
          {'amount': '1.00'},
          {'amount': '2.00'},
        ]),
        throwsA(isA<ApiServerException>()),
      );
      expect(api.requests, hasLength(1));
    });
  });

  group('overtime settings', () {
    test('getOvertimeSettings GETs and parses the settings', () async {
      api.enqueue(200, overtimeSettingsJson(hourlyBaseRate: '42.00'));

      final s = await repo.getOvertimeSettings();

      expect(api.last.path, '/income/overtime/settings');
      expect(s.hourlyBaseRate, 42.0);
      expect(s.overtimeMultiplier, 1.5);
      expect(s.estimatedTaxRate, 0.25);
    });

    test('updateOvertimeSettings PATCHes the writable fields', () async {
      api.enqueue(200, overtimeSettingsJson(hourlyBaseRate: '35.00'));

      final saved = await repo.updateOvertimeSettings(
        OvertimeSettings(
          hourlyBaseRate: 35,
          overtimeMultiplier: 2,
          estimatedTaxRate: 0.3,
        ),
      );

      expect(api.last.method, 'PATCH');
      expect(api.last.path, '/income/overtime/settings');
      expect(api.last.jsonBody, {
        'hourly_base_rate': '35.00',
        'overtime_multiplier': '2.00',
        'estimated_tax_rate': '0.30',
      });
      expect(saved.hourlyBaseRate, 35.0);
    });

    test('a 422 from the settings endpoint surfaces as validation', () async {
      api.enqueue(422, {'detail': 'tax rate must be 0..1'});
      await expectLater(
        repo.updateOvertimeSettings(
          OvertimeSettings(
            hourlyBaseRate: 1,
            overtimeMultiplier: 1,
            estimatedTaxRate: 5,
          ),
        ),
        throwsA(isA<ApiValidationException>()),
      );
    });
  });

  group('getOvertimeProjection', () {
    test('POSTs hours and contribution only, without a goal', () async {
      api.enqueue(
        200,
        overtimeProjectionJson(
          totalHoursNeeded: null,
          monthsStandard: null,
          monthsWithOvertime: null,
          monthsSaved: null,
        ),
      );

      final p = await repo.getOvertimeProjection(overtimeHoursPerWeek: 5);

      expect(api.last.method, 'POST');
      expect(api.last.path, '/income/overtime/projections');
      expect(api.last.jsonBody, {
        'overtime_hours_per_week': '5.00',
        'standard_contribution': '0.00',
      });
      expect(p.netHourlyRate, 33.75);
      expect(p.monthsSaved, isNull);
    });

    test('includes goal and subgoal ids when given', () async {
      api.enqueue(200, overtimeProjectionJson());

      final p = await repo.getOvertimeProjection(
        overtimeHoursPerWeek: 10,
        goalId: 'goal-1',
        subgoalId: 'sub-1',
        standardContribution: 200,
      );

      expect(api.last.jsonBody, {
        'overtime_hours_per_week': '10.00',
        'standard_contribution': '200.00',
        'goal_id': 'goal-1',
        'subgoal_id': 'sub-1',
      });
      expect(p.monthsSaved, 11.53);
    });
  });
}
