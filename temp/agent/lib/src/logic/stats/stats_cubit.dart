import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stats.dart';
import '../../repositories/misc_repository.dart';

abstract class StatsState extends Equatable {
  const StatsState();
  @override
  List<Object?> get props => [];
}

class StatsInitial extends StatsState {}
class StatsLoading extends StatsState {}
class StatsLoaded extends StatsState {
  final StatsOverview overview;
  final List<Map<String, dynamic>> continueWatching;
  const StatsLoaded(this.overview, this.continueWatching);
  @override
  List<Object?> get props => [overview, continueWatching];
}
class StatsFailure extends StatsState {
  final String message;
  const StatsFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class StatsCubit extends Cubit<StatsState> {
  final MiscRepository _miscRepository;

  StatsCubit(this._miscRepository) : super(StatsInitial());

  Future<void> loadStats() async {
    emit(StatsLoading());
    try {
      final overview = await _miscRepository.getStatsOverview();
      final continueWatching = await _miscRepository.getContinueWatching();
      emit(StatsLoaded(overview, continueWatching));
    } catch (e) {
      emit(StatsFailure(e.toString()));
    }
  }
}
