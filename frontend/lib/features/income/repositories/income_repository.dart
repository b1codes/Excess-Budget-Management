import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/income.dart';

class IncomeRepository {
  final SupabaseClient supabase;

  IncomeRepository({required this.supabase});

  Future<List<Income>> getIncome() async {
    final response = await supabase
        .from('extra_income')
        .select()
        .order('date_received', ascending: false)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Income.fromJson(e)).toList();
  }

  Future<void> deleteIncome(String id) async {
    await supabase.from('extra_income').delete().eq('id', id);
  }

  Future<void> bulkInsertExtraIncome(
    List<Map<String, dynamic>> incomeEntries,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final rowsToInsert = incomeEntries
        .map((e) => {...e, 'user_id': userId})
        .toList();

    await supabase.from('extra_income').insert(rowsToInsert);
  }
}
