import 'package:frontend/core/utils/json_parsing.dart';

class SubGoal {
  final String id;
  final String goalId;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdAt;

  SubGoal({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdAt,
  });

  bool get isCompleted => targetAmount > 0 && currentAmount >= targetAmount;

  factory SubGoal.fromJson(Map<String, dynamic> json) {
    return SubGoal(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      // The API infers the owner from the auth token and omits user_id.
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      targetAmount: parseAmount(json['target_amount']),
      currentAmount: parseAmount(json['current_amount']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal_id': goalId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
    };
  }
}
