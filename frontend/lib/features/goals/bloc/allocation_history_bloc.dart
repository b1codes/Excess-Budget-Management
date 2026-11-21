import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../repositories/goal_repository.dart';
import 'allocation_history_event.dart';
import 'allocation_history_state.dart';

class AllocationHistoryBloc
    extends Bloc<AllocationHistoryEvent, AllocationHistoryState> {
  final GoalRepository goalRepository;

  AllocationHistoryBloc({required this.goalRepository})
    : super(AllocationHistoryInitial()) {
    on<FetchAllocationHistory>((event, emit) async {
      emit(AllocationHistoryLoading());
      try {
        // The API returns ids only, so look goal names up separately. The
        // names are a nicety: if goals fail to load, still show the history.
        final (allocations, goalNames) = await (
          goalRepository.getAllocations(),
          goalRepository
              .getGoals()
              .then((goals) => {for (final g in goals) g.id: g.name})
              .catchError((Object _) => <String, String>{}),
        ).wait;

        final List<AllocationListItem> groupedItems = [];
        String? currentMonth;

        for (final allocation in allocations) {
          final monthStr = DateFormat('MMMM yyyy').format(allocation.createdAt);
          if (monthStr != currentMonth) {
            groupedItems.add(AllocationMonthHeader(monthStr));
            currentMonth = monthStr;
          }
          groupedItems.add(
            AllocationItem(
              allocation.goalName != null
                  ? allocation
                  : allocation.withGoalName(goalNames[allocation.goalId]),
            ),
          );
        }

        emit(AllocationHistoryLoaded(groupedItems));
      } catch (e) {
        emit(AllocationHistoryError(e.toString()));
      }
    });
  }
}
