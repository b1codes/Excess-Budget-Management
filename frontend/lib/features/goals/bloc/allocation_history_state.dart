import '../models/allocation.dart';

sealed class AllocationListItem {}

class AllocationMonthHeader extends AllocationListItem {
  final String monthYear;
  AllocationMonthHeader(this.monthYear);
}

class AllocationItem extends AllocationListItem {
  final GoalAllocation allocation;
  AllocationItem(this.allocation);
}

abstract class AllocationHistoryState {}

class AllocationHistoryInitial extends AllocationHistoryState {}

class AllocationHistoryLoading extends AllocationHistoryState {}

class AllocationHistoryLoaded extends AllocationHistoryState {
  final List<AllocationListItem> items;

  AllocationHistoryLoaded(this.items);
}

class AllocationHistoryError extends AllocationHistoryState {
  final String message;

  AllocationHistoryError(this.message);
}
