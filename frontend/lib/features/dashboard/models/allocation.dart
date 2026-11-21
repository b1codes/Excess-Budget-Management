import 'package:frontend/core/utils/json_parsing.dart';

class Allocation {
  final String type; // "goal" or "account"
  final String id;
  final String name;
  final double amount;
  final String reason;

  Allocation({
    required this.type,
    required this.id,
    required this.name,
    required this.amount,
    required this.reason,
  });

  factory Allocation.fromJson(Map<String, dynamic> json) {
    return Allocation(
      type: json['type'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      amount: parseAmount(json['amount']),
      reason: json['reason'] as String,
    );
  }
}

/// The response of POST /suggestions/generate (SuggestOut).
class SuggestionResult {
  final List<Allocation> allocations;
  final double totalAllocated;

  /// The model's explanation of the split as a whole.
  final String reasoning;

  SuggestionResult({
    required this.allocations,
    required this.totalAllocated,
    this.reasoning = '',
  });

  factory SuggestionResult.fromJson(Map<String, dynamic> json) {
    final allocList = json['allocations'] as List? ?? const [];
    return SuggestionResult(
      allocations: allocList
          .map((i) => Allocation.fromJson(i as Map<String, dynamic>))
          .toList(),
      totalAllocated: parseAmount(json['totalAllocated']),
      reasoning: json['reasoning'] as String? ?? '',
    );
  }
}
