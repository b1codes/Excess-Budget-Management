// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  budgetCategoryId: json['budget_category_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String?,
  date: DateTime.parse(json['date'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'budget_category_id': instance.budgetCategoryId,
  'amount': instance.amount,
  'description': instance.description,
  'date': instance.date.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
