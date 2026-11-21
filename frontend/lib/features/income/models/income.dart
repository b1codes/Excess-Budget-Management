import 'package:json_annotation/json_annotation.dart';
import 'package:frontend/core/utils/json_parsing.dart';

part 'income.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Income {
  final String id;
  // The API infers the owner from the auth token and omits user_id.
  @JsonKey(defaultValue: '')
  final String userId;
  @JsonKey(fromJson: parseAmount)
  final double amount;
  final String? description;
  final DateTime dateReceived;
  final DateTime createdAt;
  final String? accountId;
  @JsonKey(name: 'budget_category_id')
  final String? categoryId;

  Income({
    required this.id,
    required this.userId,
    required this.amount,
    this.description,
    required this.dateReceived,
    required this.createdAt,
    this.accountId,
    this.categoryId,
  });

  factory Income.fromJson(Map<String, dynamic> json) => _$IncomeFromJson(json);
  Map<String, dynamic> toJson() => _$IncomeToJson(this);
}
