import 'package:flutter_bloc/flutter_bloc.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
import '../repositories/suggestion_repository.dart';
import '../../accounts/repositories/account_repository.dart';
import '../../goals/repositories/goal_repository.dart';
import '../../auth/repositories/profile_repository.dart';
import '../../budget/repositories/budget_repository.dart';
import '../../accounts/models/account.dart';
import '../../budget/models/budget_category.dart';
import '../../goals/models/goal.dart';
import '../../goals/models/allocation.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SuggestionRepository suggestionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;
  final ProfileRepository profileRepository;
  final BudgetRepository budgetRepository;

  DashboardBloc({
    required this.suggestionRepository,
    required this.accountRepository,
    required this.goalRepository,
    required this.profileRepository,
    required this.budgetRepository,
  }) : super(DashboardInitial()) {
    on<DashboardInitialDataRequested>(_onDashboardInitialDataRequested);
    on<DashboardRefreshRequested>(_onDashboardRefreshRequested);
    on<GenerateSuggestionsRequested>(_onGenerateSuggestionsRequested);
    on<AcceptSuggestionRequested>(_onAcceptSuggestionRequested);
    on<DashboardResetRequested>(_onDashboardResetRequested);
  }

  /// Bumped by [DashboardResetRequested]. A load that started before the
  /// reset (for the previous user) checks it and drops its result.
  int _generation = 0;

  Future<void> _onDashboardInitialDataRequested(
    DashboardInitialDataRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    await _loadData(emit);
  }

  Future<void> _onDashboardRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    final current = state;
    if (current is DashboardSuggestionsLoaded || current is DashboardLoading) {
      return;
    }
    // Keep the current figures on screen while the fresh ones load.
    if (current is! DashboardDataLoaded) emit(DashboardLoading());
    await _loadData(emit);
  }

  Future<void> _loadData(Emitter<DashboardState> emit) async {
    final generation = _generation;
    try {
      final results = await Future.wait([
        accountRepository.getAccounts(),
        budgetRepository.getBudgetCategories(),
        goalRepository.getGoals(),
        goalRepository.getAllocations(),
      ]);
      if (generation != _generation) return;

      emit(
        DashboardDataLoaded(
          accounts: results[0] as List<Account>,
          budgetCategories: results[1] as List<BudgetCategory>,
          goals: results[2] as List<Goal>,
          recentAllocations: results[3] as List<GoalAllocation>,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onGenerateSuggestionsRequested(
    GenerateSuggestionsRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    try {
      // The Django backend gathers context server-side from the authenticated
      // user — accounts, goals, allocations, and profile are not sent by the
      // client. Only excess_funds is needed.
      final result = await suggestionRepository.getSuggestions(
        excessFunds: event.excessFunds,
      );

      final goals = await goalRepository.getGoals();
      emit(DashboardSuggestionsLoaded(result, goals));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onAcceptSuggestionRequested(
    AcceptSuggestionRequested event,
    Emitter<DashboardState> emit,
  ) async {
    final allocation = event.allocation;

    try {
      if (allocation.type == 'goal') {
        // The backend rolls each allocation into the goal's progress (and the
        // subgoal's, when sub_goal_id is set), so allocations are the only
        // write needed. Patching subgoal amounts as well would count the
        // money twice.
        final distribution = event.subGoalDistribution ?? const {};
        if (distribution.isNotEmpty) {
          for (final entry in distribution.entries) {
            if (entry.value <= 0) continue;
            await goalRepository.insertAllocation(
              allocation.id,
              entry.value,
              subGoalId: entry.key,
            );
          }
        } else {
          await goalRepository.insertAllocation(
            allocation.id,
            allocation.amount,
          );
        }
      } else {
        final accounts = await accountRepository.getAccounts();
        final account = accounts.firstWhere((a) => a.id == allocation.id);

        await accountRepository.updateAccountBalance(
          allocation.id,
          account.balance + allocation.amount,
        );
      }

      // A manual allocation from the metrics view changes Goal Progress, so
      // reload it. A suggestion list stays as it is, so the user can accept
      // the rest.
      if (state is DashboardDataLoaded) add(DashboardRefreshRequested());
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  void _onDashboardResetRequested(
    DashboardResetRequested event,
    Emitter<DashboardState> emit,
  ) {
    _generation++;
    emit(DashboardInitial());
  }
}
