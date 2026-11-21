import 'package:json_annotation/json_annotation.dart';
import 'package:frontend/core/utils/json_parsing.dart';

part 'expense.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Expense {
  final String id;
  // The API infers the owner from the auth token and omits user_id.
  @JsonKey(defaultValue: '')
  final String userId;
  final String budgetCategoryId;
  @JsonKey(fromJson: parseAmount)
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final String? accountId;

  Expense({
    required this.id,
    required this.userId,
    required this.budgetCategoryId,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
    this.accountId,
  });

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);
}
