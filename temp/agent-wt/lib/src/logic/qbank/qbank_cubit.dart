import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/quiz.dart';
import '../../repositories/quiz_repository.dart';

abstract class QBankState extends Equatable {
  const QBankState();
  @override
  List<Object?> get props => [];
}

class QBankInitial extends QBankState {}
class QBankLoading extends QBankState {}
class QBankLoaded extends QBankState {
  final List<Quiz> quizzes;
  const QBankLoaded(this.quizzes);
  @override
  List<Object?> get props => [quizzes];
}
class QBankFailure extends QBankState {
  final String message;
  const QBankFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class QBankCubit extends Cubit<QBankState> {
  final QuizRepository _quizRepository;

  QBankCubit(this._quizRepository) : super(QBankInitial());

  // In a real app, we might fetch subjects first, but here we'll just mock it or fetch generic quizzes
  Future<void> loadQuizzes() async {
    emit(QBankLoading());
    try {
      // Assuming we have a way to get all quizzes or specific ones
      // For now, let's just use a placeholder or handle the empty list
      emit(const QBankLoaded([]));
    } catch (e) {
      emit(QBankFailure(e.toString()));
    }
  }

  Future<Map<String, dynamic>> submitQuiz(String quizId, Map<String, String> answers) async {
    return await _quizRepository.submitQuiz(quizId, answers);
  }
}
