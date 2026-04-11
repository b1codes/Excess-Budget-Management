import '../models/allocation.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardSuggestionsLoaded extends DashboardState {
  final SuggestionResult result;

  DashboardSuggestionsLoaded(this.result);
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);
}
