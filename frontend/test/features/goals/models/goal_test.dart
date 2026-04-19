import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/models/sub_goal.dart';

void main() {
  group('Goal Model - isCompleted', () {
    test('should return true when currentAmount >= targetAmount', () {
      final goal = Goal(
        id: '1',
        userId: 'u1',
        name: 'Test Goal',
        targetAmount: 100,
        currentAmount: 100,
        type: 'savings',
        category: 'leisure',
        createdAt: DateTime.now(),
      );
      expect(goal.isCompleted, isTrue);

      final goal2 = Goal(
        id: '2',
        userId: 'u1',
        name: 'Test Goal 2',
        targetAmount: 100,
        currentAmount: 150,
        type: 'savings',
        category: 'leisure',
        createdAt: DateTime.now(),
      );
      expect(goal2.isCompleted, isTrue);
    });

    test('should return false when currentAmount < targetAmount', () {
      final goal = Goal(
        id: '1',
        userId: 'u1',
        name: 'Test Goal',
        targetAmount: 100,
        currentAmount: 99.9,
        type: 'savings',
        category: 'leisure',
        createdAt: DateTime.now(),
      );
      expect(goal.isCompleted, isFalse);
    });

    test('should return false when targetAmount is 0', () {
      final goal = Goal(
        id: '1',
        userId: 'u1',
        name: 'Test Goal',
        targetAmount: 0,
        currentAmount: 0,
        type: 'savings',
        category: 'leisure',
        createdAt: DateTime.now(),
      );
      expect(goal.isCompleted, isFalse);
    });
  });

  group('SubGoal Model - isCompleted', () {
    test('should return true when currentAmount >= targetAmount', () {
      final subGoal = SubGoal(
        id: 's1',
        goalId: 'g1',
        userId: 'u1',
        name: 'Sub Goal',
        targetAmount: 50,
        currentAmount: 50,
        createdAt: DateTime.now(),
      );
      expect(subGoal.isCompleted, isTrue);
    });

    test('should return false when currentAmount < targetAmount', () {
      final subGoal = SubGoal(
        id: 's1',
        goalId: 'g1',
        userId: 'u1',
        name: 'Sub Goal',
        targetAmount: 50,
        currentAmount: 49,
        createdAt: DateTime.now(),
      );
      expect(subGoal.isCompleted, isFalse);
    });
  });
}
