import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/budget/presentation/screens/budget_categories_screen.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';

class MockBudgetBloc extends Mock implements BudgetBloc {}

void main() {
  late MockBudgetBloc mockBudgetBloc;

  setUp(() {
    mockBudgetBloc = MockBudgetBloc();
    when(() => mockBudgetBloc.state).thenReturn(BudgetInitial());
    when(() => mockBudgetBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<BudgetBloc>.value(
        value: mockBudgetBloc,
        child: const BudgetCategoriesScreen(),
      ),
    );
  }

  testWidgets('renders SliverList in compact mode', (
    WidgetTester tester,
  ) async {
    // Set screen size to compact
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    final categories = [
      BudgetCategory(
        id: '1',
        userId: 'u1',
        name: 'Food',
        limitAmount: 500,
        spentAmount: 100,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBudgetBloc.state).thenReturn(BudgetLoaded(categories));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('renders SliverGrid in medium mode', (WidgetTester tester) async {
    // Set screen size to medium
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;

    final categories = [
      BudgetCategory(
        id: '1',
        userId: 'u1',
        name: 'Food',
        limitAmount: 500,
        spentAmount: 100,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBudgetBloc.state).thenReturn(BudgetLoaded(categories));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byType(SliverList), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('renders SliverGrid with 3 columns in expanded mode', (
    WidgetTester tester,
  ) async {
    // Set screen size to expanded
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;

    final categories = [
      BudgetCategory(
        id: '1',
        userId: 'u1',
        name: 'Food',
        limitAmount: 500,
        spentAmount: 100,
        createdAt: DateTime.now(),
      ),
    ];

    when(() => mockBudgetBloc.state).thenReturn(BudgetLoaded(categories));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    final gridFinder = find.byType(SliverGrid);
    expect(gridFinder, findsOneWidget);

    final grid = tester.widget<SliverGrid>(gridFinder);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
