import 'package:equatable/equatable.dart';
import '../../income/models/income.dart';

abstract class TransactionIncomeState extends Equatable {
  const TransactionIncomeState();

  @override
  List<Object?> get props => [];
}

class TransactionIncomeInitial extends TransactionIncomeState {}

class TransactionIncomeLoading extends TransactionIncomeState {}

class TransactionIncomeLoaded extends TransactionIncomeState {
  final List<Income> income;
  const TransactionIncomeLoaded(this.income);

  @override
  List<Object?> get props => [income];
}

class TransactionIncomeError extends TransactionIncomeState {
  final String message;
  const TransactionIncomeError(this.message);

  @override
  List<Object?> get props => [message];
}
