import 'package:equatable/equatable.dart';
import '../../budget/models/expense.dart';

abstract class TransactionExpensesState extends Equatable {
  const TransactionExpensesState();

  @override
  List<Object?> get props => [];
}

class TransactionExpensesInitial extends TransactionExpensesState {}

class TransactionExpensesLoading extends TransactionExpensesState {}

class TransactionExpensesLoaded extends TransactionExpensesState {
  final List<Expense> expenses;
  const TransactionExpensesLoaded(this.expenses);

  @override
  List<Object?> get props => [expenses];
}

class TransactionExpensesError extends TransactionExpensesState {
  final String message;
  const TransactionExpensesError(this.message);

  @override
  List<Object?> get props => [message];
}
