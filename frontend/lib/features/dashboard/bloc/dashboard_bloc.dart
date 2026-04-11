import 'package:flutter_bloc/flutter_bloc.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';
import '../repositories/suggestion_repository.dart';
import '../../accounts/repositories/account_repository.dart';
import '../../goals/repositories/goal_repository.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SuggestionRepository suggestionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;

  DashboardBloc({
    required this.suggestionRepository,
    required this.accountRepository,
    required this.goalRepository,
  }) : super(DashboardInitial()) {
    on<GenerateSuggestionsRequested>(_onGenerateSuggestionsRequested);
    on<DashboardResetRequested>(_onDashboardResetRequested);
  }

  Future<void> _onGenerateSuggestionsRequested(
      GenerateSuggestionsRequested event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());

    try {
      final accounts = await accountRepository.getAccounts();
      final goals = await goalRepository.getGoals();

      final result = await suggestionRepository.getSuggestions(
        excessFunds: event.excessFunds,
        accounts: accounts,
        goals: goals,
      );

      emit(DashboardSuggestionsLoaded(result));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  void _onDashboardResetRequested(DashboardResetRequested event, Emitter<DashboardState> emit) {
    emit(DashboardInitial());
  }
}
