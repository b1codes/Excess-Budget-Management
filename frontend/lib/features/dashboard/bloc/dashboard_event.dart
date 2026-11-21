import '../models/allocation.dart';

abstract class DashboardEvent {}

class DashboardInitialDataRequested extends DashboardEvent {}

/// Reloads the metrics without a loading spinner, e.g. when the overview is
/// shown again after changes in another tab. Ignored while suggestions are
/// on screen, so the user doesn't lose them.
class DashboardRefreshRequested extends DashboardEvent {}

class GenerateSuggestionsRequested extends DashboardEvent {
  final double excessFunds;

  GenerateSuggestionsRequested(this.excessFunds);
}

class AcceptSuggestionRequested extends DashboardEvent {
  final Allocation allocation;
  final Map<String, double>? subGoalDistribution;

  AcceptSuggestionRequested(this.allocation, {this.subGoalDistribution});
}

/// Forgets everything loaded, e.g. on sign-out.
class DashboardResetRequested extends DashboardEvent {}
