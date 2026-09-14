import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/qbank.dart';
import '../../repositories/quiz_repository.dart';

abstract class QBankState extends Equatable {
  const QBankState();
  @override
  List<Object?> get props => [];
}

class QBankInitial extends QBankState {}
class QBankLoading extends QBankState {}
class QBankLoaded extends QBankState {
  final List<QBank> qbanks;
  final List<QBankSession> recentSessions;
  const QBankLoaded({required this.qbanks, required this.recentSessions});
  @override
  List<Object?> get props => [qbanks, recentSessions];
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

  Future<void> loadQBanks() async {
    emit(QBankLoading());
    try {
      final qbanks = await _quizRepository.getQBanks();
      final recentSessions = await _quizRepository.getRecentSessions();
      emit(QBankLoaded(qbanks: qbanks, recentSessions: recentSessions));
    } catch (e) {
      emit(QBankFailure(e.toString()));
    }
  }

  Future<QBankSession?> createSession(String qbankId, Map<String, dynamic> config) async {
    try {
      final session = await _quizRepository.createQBankSession(qbankId, config);
      await loadQBanks();
      return session;
    } catch (e) {
      emit(QBankFailure(e.toString()));
      return null;
    }
  }

  Future<Map<String, dynamic>> submitQuiz(String quizId, Map<String, String> answers) async {
    return await _quizRepository.submitQuiz(quizId, answers);
  }
}
