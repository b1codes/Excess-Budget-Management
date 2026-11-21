import 'package:equatable/equatable.dart';
import 'package:frontend/core/utils/json_parsing.dart';

class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double balance;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.balance,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      // The API infers the owner from the auth token and omits user_id.
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      balance: parseAmount(json['balance']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'balance': balance};
  }

  @override
  List<Object?> get props => [id, userId, name, balance, createdAt];
}
