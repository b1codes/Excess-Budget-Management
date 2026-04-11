import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';

class GoalRepository {
  final SupabaseClient supabase;

  GoalRepository({required this.supabase});

  Future<List<Goal>> getGoals() async {
    final response = await supabase.from('goals').select().order('created_at', ascending: true);
    return (response as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<Goal> addGoal(String name, double targetAmount, String type, {DateTime? targetDate}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await supabase.from('goals').insert({
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'type': type,
      if (targetDate != null) 'target_date': targetDate.toIso8601String(),
    }).select().single();

    return Goal.fromJson(response);
  }

  Future<Goal> updateGoalCurrentAmount(String id, double currentAmount) async {
    final response = await supabase.from('goals').update({
      'current_amount': currentAmount,
    }).eq('id', id).select().single();

    return Goal.fromJson(response);
  }

  Future<void> deleteGoal(String id) async {
    await supabase.from('goals').delete().eq('id', id);
  }
}
