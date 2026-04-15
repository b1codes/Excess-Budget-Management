import '../models/allocation.dart';

abstract class DashboardEvent {}

class GenerateSuggestionsRequested extends DashboardEvent {
  final double excessFunds;

  GenerateSuggestionsRequested(this.excessFunds);
}

class AcceptSuggestionRequested extends DashboardEvent {
  final Allocation allocation;

  AcceptSuggestionRequested(this.allocation);
}

class DashboardResetRequested extends DashboardEvent {}
