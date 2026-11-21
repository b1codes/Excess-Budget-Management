// Self-tests for the contract checker, so the contract tests can't pass by
// accident because the checker accepts everything.

import 'package:flutter_test/flutter_test.dart';

import 'openapi_contract.dart';

void main() {
  final contract = OpenApiContract.load();

  Map<String, dynamic> subgoal() => {
    'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    'goal_id': '3fa85f64-5717-4562-b3fc-2c963f66afa7',
    'name': 'Tyres',
    'target_amount': '300.00',
    'current_amount': '0.00',
    'created_at': '2026-01-15T10:30:00Z',
  };

  test('loads the snapshot', () {
    expect(contract.document['openapi'], startsWith('3.'));
    expect(contract.operationIds.length, greaterThan(40));
  });

  group('validate', () {
    test('accepts a matching value', () {
      expect(contract.validateAgainst(subgoal(), 'SubgoalOut'), isEmpty);
    });

    test('rejects a missing required key', () {
      expect(
        contract.validateAgainst(subgoal()..remove('name'), 'SubgoalOut'),
        [r'$: missing "name"'],
      );
    });

    test('rejects a key the schema does not list', () {
      expect(
        contract.validateAgainst({...subgoal(), 'user_id': 'u'}, 'SubgoalOut'),
        [r'$: "user_id" is not in SubgoalOut'],
      );
    });

    test('rejects money sent as a number in a response', () {
      expect(
        contract.validateAgainst({
          ...subgoal(),
          'target_amount': 300,
        }, 'SubgoalOut'),
        [r'$.target_amount: expected a string, got 300'],
      );
    });

    test('checks formats unless ids are opaque', () {
      final value = {...subgoal(), 'id': 'sub-1'};
      expect(contract.validateAgainst(value, 'SubgoalOut'), [
        r'$.id: "sub-1" is not a uuid',
      ]);
      expect(
        contract.validateAgainst(value, 'SubgoalOut', opaqueIds: true),
        isEmpty,
      );
      expect(
        contract.validateAgainst({
          ...subgoal(),
          'created_at': '2026-01-15',
        }, 'SubgoalOut'),
        [r'$.created_at: "2026-01-15" is not an ISO 8601 date-time'],
      );
    });

    test('follows refs into arrays of nested objects', () {
      final goal = contract.exampleOf('GoalOut', full: true) as Map;
      (goal['sub_goals'] as List).first['extra'] = 1;
      expect(contract.validateAgainst(goal, 'GoalOut'), [
        r'$.sub_goals[0]: "extra" is not in SubgoalOut',
      ]);
    });

    test('nullable fields accept null; enums reject other values', () {
      final goal = contract.exampleOf('GoalOut', full: true) as Map;
      expect(
        contract.validateAgainst({...goal, 'target_date': null}, 'GoalOut'),
        isEmpty,
      );
      expect(contract.validateAgainst({...goal, 'type': 'weekly'}, 'GoalOut'), [
        r'$.type: "weekly" is not one of [short_term, long_term]',
      ]);
    });

    test('requests must send Decimal fields as strings', () {
      final body = {
        'budget_category_id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'amount': 0.1 + 0.2,
        'date': '2026-01-15',
      };
      expect(
        contract.validateAgainst(
          body,
          'ExpenseIn',
          direction: Direction.request,
        ),
        [
          r'$.amount: send Decimal fields as a string (e.g. "0.30"), '
              'not the number 0.30000000000000004',
        ],
      );
      expect(
        contract.validateAgainst(
          {...body, 'amount': '0.30'},
          'ExpenseIn',
          direction: Direction.request,
        ),
        isEmpty,
      );
      expect(
        contract.validateAgainst(
          {...body, 'amount': '0.305'},
          'ExpenseIn',
          direction: Direction.request,
        ),
        isNotEmpty,
      );
    });

    test('decimal strings must be numbers within the allowed places', () {
      List<String> check(String amount) => contract.validateAgainst({
        ...subgoal(),
        'target_amount': amount,
      }, 'SubgoalOut');
      expect(check('12.50'), isEmpty);
      expect(check('-3'), isEmpty);
      expect(check('twelve'), [
        r'$.target_amount: "twelve" is not a decimal number',
      ]);
      expect(check('1.234'), [
        r'$.target_amount: "1.234" has more than 2 decimal places',
      ]);
    });

    test('checks numeric ranges', () {
      expect(
        contract.validateAgainst(
          {'default_savings_ratio': 1.5},
          'MePatchIn',
          direction: Direction.request,
        ),
        isNotEmpty,
      );
    });
  });

  group('example', () {
    test('full and minimal examples both satisfy their schema', () {
      for (final name in contract.schemas.keys) {
        for (final full in [true, false]) {
          expect(
            contract.validateAgainst(
              contract.exampleOf(name, full: full),
              name,
            ),
            isEmpty,
            reason: '$name (full: $full)',
          );
        }
      }
    });

    test('minimal examples null out optional data and empty arrays', () {
      final goal = contract.exampleOf('GoalOut', full: false) as Map;
      expect(goal.containsKey('target_date'), isFalse);
      expect(goal['sub_goals'], isEmpty);
      final expense = contract.exampleOf('ExpenseOut', full: false) as Map;
      expect(expense['account_id'], isNull);
    });
  });

  group('match', () {
    test('prefers literal segments over parameters', () {
      expect(
        contract.match('GET', '/allocations/summary')!.template,
        '/api/v1/allocations/summary',
      );
      expect(
        contract.match('GET', '/allocations/abc')!.template,
        '/api/v1/allocations/{allocation_id}',
      );
    });

    test('rejects unknown paths and methods', () {
      expect(contract.match('GET', '/nope'), isNull);
      expect(contract.match('PUT', '/accounts/abc'), isNull);
    });
  });
}
