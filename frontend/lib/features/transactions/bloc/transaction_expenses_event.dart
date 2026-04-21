import 'package:equatable/equatable.dart';

abstract class TransactionExpensesEvent extends Equatable {
  const TransactionExpensesEvent();

  @override
  List<Object?> get props => [];
}

class FetchTransactionExpenses extends TransactionExpensesEvent {}

class DeleteTransactionExpense extends TransactionExpensesEvent {
  final String id;
  const DeleteTransactionExpense(this.id);

  @override
  List<Object?> get props => [id];
}
