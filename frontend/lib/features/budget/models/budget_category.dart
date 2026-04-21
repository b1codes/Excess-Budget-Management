class BudgetCategory {
  final String id;
  final String userId;
  final String name;
  final double limitAmount;
  final double spentAmount;
  final int? iconCode;
  final String? colorHex;
  final DateTime createdAt;

  BudgetCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.limitAmount,
    required this.spentAmount,
    this.iconCode,
    this.colorHex,
    required this.createdAt,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      limitAmount: (json['limit_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      iconCode: json['icon_code'] as int?,
      colorHex: json['color_hex'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'limit_amount': limitAmount,
      'spent_amount': spentAmount,
      'icon_code': iconCode,
      'color_hex': colorHex,
    };
  }
}
