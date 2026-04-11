abstract class DashboardEvent {}

class GenerateSuggestionsRequested extends DashboardEvent {
  final double excessFunds;

  GenerateSuggestionsRequested(this.excessFunds);
}

class DashboardResetRequested extends DashboardEvent {}
