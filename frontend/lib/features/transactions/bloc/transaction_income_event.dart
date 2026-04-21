import 'package:equatable/equatable.dart';

abstract class TransactionIncomeEvent extends Equatable {
  const TransactionIncomeEvent();

  @override
  List<Object?> get props => [];
}

class FetchTransactionIncome extends TransactionIncomeEvent {}

class DeleteTransactionIncome extends TransactionIncomeEvent {
  final String id;
  const DeleteTransactionIncome(this.id);

  @override
  List<Object?> get props => [id];
}
