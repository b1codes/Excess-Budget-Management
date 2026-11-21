class OvertimeSettings {
  final double hourlyBaseRate;
  final double overtimeMultiplier;
  final double estimatedTaxRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OvertimeSettings({
    required this.hourlyBaseRate,
    required this.overtimeMultiplier,
    required this.estimatedTaxRate,
    this.createdAt,
    this.updatedAt,
  });

  factory OvertimeSettings.fromJson(Map<String, dynamic> json) {
    return OvertimeSettings(
      hourlyBaseRate:
          double.tryParse(json['hourly_base_rate'].toString()) ?? 0.0,
      overtimeMultiplier:
          double.tryParse(json['overtime_multiplier'].toString()) ?? 1.5,
      estimatedTaxRate:
          double.tryParse(json['estimated_tax_rate'].toString()) ?? 0.25,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  /// The PATCH body. The API's Decimal fields take strings with at most two
  /// decimal places; a raw double such as 0.1 + 0.2 would be rejected.
  Map<String, dynamic> toJson() {
    return {
      'hourly_base_rate': hourlyBaseRate.toStringAsFixed(2),
      'overtime_multiplier': overtimeMultiplier.toStringAsFixed(2),
      'estimated_tax_rate': estimatedTaxRate.toStringAsFixed(2),
    };
  }

  OvertimeSettings copyWith({
    double? hourlyBaseRate,
    double? overtimeMultiplier,
    double? estimatedTaxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OvertimeSettings(
      hourlyBaseRate: hourlyBaseRate ?? this.hourlyBaseRate,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      estimatedTaxRate: estimatedTaxRate ?? this.estimatedTaxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
