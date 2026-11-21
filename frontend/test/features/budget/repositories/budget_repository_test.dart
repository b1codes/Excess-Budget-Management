import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late BudgetRepository repo;

  setUp(() {
    api = FakeApi();
    repo = BudgetRepository(client: api.client);
  });

  group('getBudgetCategories', () {
    test('GETs /budget/categories and parses each category', () async {
      api.enqueue(200, [
        budgetCategoryJson(id: 'cat-1', limitAmount: '300.00'),
        budgetCategoryJson(id: 'cat-2', categoryType: 'income'),
      ]);

      final categories = await repo.getBudgetCategories();

      expect(api.last.method, 'GET');
      expect(api.last.path, '/budget/categories');
      expect(categories.map((c) => c.id), ['cat-1', 'cat-2']);
      expect(categories[0].limitAmount, 300.0);
      expect(categories[1].type, BudgetCategoryType.income);
    });

    test('returns an empty list for an empty array', () async {
      api.enqueue(200, <dynamic>[]);
      expect(await repo.getBudgetCategories(), isEmpty);
    });

    test('maps a 500 to ApiServerException', () async {
      api.enqueue(500, {'detail': 'boom'});
      await expectLater(
        repo.getBudgetCategories(),
        throwsA(isA<ApiServerException>()),
      );
    });
  });

  group('getBudgetCategoriesStream', () {
    test('emits immediately, then polls every 30 seconds', () {
      fakeAsync((async) {
        api.enqueue(200, [budgetCategoryJson(id: 'a')]);
        api.enqueue(200, [budgetCategoryJson(id: 'b')]);
        final seen = <List<String>>[];
        final sub = repo.getBudgetCategoriesStream().listen(
          (cats) => seen.add(cats.map((c) => c.id).toList()),
        );

        async.elapse(const Duration(milliseconds: 1));
        expect(seen, [
          ['a'],
        ]);

        async.elapse(const Duration(seconds: 30));
        expect(seen, [
          ['a'],
          ['b'],
        ]);
        sub.cancel();
      });
    });
  });

  group('getExpenses', () {
    test('GETs /expenses without filters', () async {
      api.enqueue(200, [expenseJson(), expenseJson(id: 'exp-2')]);

      final expenses = await repo.getExpenses();

      expect(api.last.path, '/expenses');
      expect(api.last.query, isEmpty);
      expect(expenses, hasLength(2));
      expect(expenses.first.amount, 42.5);
    });
  });

  test('deleteExpense DELETEs /expenses/:id', () async {
    api.enqueue(204);
    await repo.deleteExpense('exp-9');
    expect(api.last.method, 'DELETE');
    expect(api.last.path, '/expenses/exp-9');
  });

  group('addBudgetCategory', () {
    test('POSTs a two-decimal limit and the default expense type', () async {
      api.enqueue(
        201,
        budgetCategoryJson(name: 'Bills', limitAmount: '299.99'),
      );

      final c = await repo.addBudgetCategory('Bills', 299.99);

      expect(api.last.method, 'POST');
      expect(api.last.path, '/budget/categories');
      expect(api.last.jsonBody, {
        'name': 'Bills',
        'limit_amount': '299.99',
        'category_type': 'expense',
      });
      expect(c.name, 'Bills');
      expect(c.limitAmount, 299.99);
    });

    test('includes icon, colour and an income type when given', () async {
      api.enqueue(201, budgetCategoryJson(categoryType: 'income'));

      await repo.addBudgetCategory(
        'Salary',
        0,
        iconCode: 0xe000,
        colorHex: '#00FF00',
        type: BudgetCategoryType.income,
      );

      expect(api.last.jsonBody, {
        'name': 'Salary',
        'limit_amount': '0.00',
        'category_type': 'income',
        'icon_code': 0xe000,
        'color_hex': '#00FF00',
      });
    });

    test(
      'maps a 422 to ApiValidationException with the server message',
      () async {
        api.enqueue(422, {
          'error': {
            'message': 'Name too long',
            'details': {'name': 'max 200'},
          },
        });

        await expectLater(
          repo.addBudgetCategory('x' * 300, 1),
          throwsA(
            isA<ApiValidationException>()
                .having((e) => e.message, 'message', 'Name too long')
                .having((e) => e.details, 'details', {'name': 'max 200'}),
          ),
        );
      },
    );
  });

  group('updateBudgetCategory', () {
    test('PATCHes name and limit only when nothing else is given', () async {
      api.enqueue(200, budgetCategoryJson());

      await repo.updateBudgetCategory('cat-1', 'Food', 50);

      expect(api.last.method, 'PATCH');
      expect(api.last.path, '/budget/categories/cat-1');
      expect(api.last.jsonBody, {'name': 'Food', 'limit_amount': '50.00'});
    });

    test('includes icon, colour and type when given', () async {
      api.enqueue(200, budgetCategoryJson());

      final c = await repo.updateBudgetCategory(
        'cat-1',
        'Food',
        50.5,
        iconCode: 1,
        colorHex: '#123456',
        type: BudgetCategoryType.income,
      );

      expect(api.last.jsonBody, {
        'name': 'Food',
        'limit_amount': '50.50',
        'icon_code': 1,
        'color_hex': '#123456',
        'category_type': 'income',
      });
      expect(c.id, 'cat-1');
    });

    test('maps a 404 to ApiNotFoundException', () async {
      api.enqueue(404, {'detail': 'Not found'});
      await expectLater(
        repo.updateBudgetCategory('missing', 'x', 1),
        throwsA(isA<ApiNotFoundException>()),
      );
    });
  });

  test('deleteBudgetCategory DELETEs /budget/categories/:id', () async {
    api.enqueue(204);
    await repo.deleteBudgetCategory('cat-3');
    expect(api.last.method, 'DELETE');
    expect(api.last.path, '/budget/categories/cat-3');
  });

  group('bulkInsertExpenses', () {
    test('POSTs each expense in order without user_id', () async {
      api.enqueue(201, expenseJson(id: 'a'));
      api.enqueue(201, expenseJson(id: 'b'));

      await repo.bulkInsertExpenses([
        {'user_id': 'u', 'amount': '1.00', 'budget_category_id': 'cat-1'},
        {'amount': '2.00', 'budget_category_id': 'cat-2'},
      ]);

      expect(api.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /expenses',
        'POST /expenses',
      ]);
      expect(api.requests[0].jsonBody, {
        'amount': '1.00',
        'budget_category_id': 'cat-1',
      });
      expect(api.requests[1].jsonBody['amount'], '2.00');
    });

    test('does not mutate the caller\'s maps', () async {
      api.enqueue(201, expenseJson());
      final entry = {'user_id': 'u', 'amount': '1.00'};
      await repo.bulkInsertExpenses([entry]);
      expect(entry, containsPair('user_id', 'u'));
    });

    test('stops at the first failure', () async {
      api.enqueue(201, expenseJson());
      api.enqueue(422, {'detail': 'bad amount'});

      await expectLater(
        repo.bulkInsertExpenses([
          {'amount': '1.00'},
          {'amount': 'x'},
          {'amount': '3.00'},
        ]),
        throwsA(isA<ApiValidationException>()),
      );
      expect(api.requests, hasLength(2));
    });

    test('sends nothing for an empty list', () async {
      await repo.bulkInsertExpenses([]);
      expect(api.requests, isEmpty);
    });
  });

  test('getCategoryExpenses filters by budget_category_id', () async {
    api.enqueue(200, [expenseJson(amount: '45.00'), expenseJson(id: 'e2')]);

    final expenses = await repo.getCategoryExpenses('cat-1');

    expect(api.last.path, '/expenses');
    expect(api.last.query, {'budget_category_id': 'cat-1'});
    expect(expenses.first.amount, 45.0);
    expect(expenses, hasLength(2));
  });

  test(
    'getCategoryIncome filters extra income by budget_category_id',
    () async {
      api.enqueue(200, [extraIncomeJson(budgetCategoryId: 'cat-7')]);

      final income = await repo.getCategoryIncome('cat-7');

      expect(api.last.path, '/income/extra');
      expect(api.last.query, {'budget_category_id': 'cat-7'});
      expect(income.single.categoryId, 'cat-7');
    },
  );
}
