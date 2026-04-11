import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/allocation.dart';
import '../../accounts/models/account.dart';
import '../../goals/models/goal.dart';

class SuggestionRepository {
  final SupabaseClient supabase;

  SuggestionRepository({required this.supabase});

  Future<SuggestionResult> getSuggestions({
    required double excessFunds,
    required List<Account> accounts,
    required List<Goal> goals,
  }) async {
    final response = await supabase.functions.invoke(
      'generate-suggestions',
      body: {
        'excessFunds': excessFunds,
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to generate suggestions: ${response.data}');
    }

    return SuggestionResult.fromJson(response.data as Map<String, dynamic>);
  }
}
