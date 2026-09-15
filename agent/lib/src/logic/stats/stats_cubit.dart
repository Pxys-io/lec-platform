import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
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

  /// Loads overview + continue-watching independently: one failing endpoint
  /// must never blank the whole home screen (real case: /stats/overview
  /// 500'd for every student while /stats/continue-watching was fine).
  Future<void> loadStats() async {
    emit(StatsLoading());
    StatsOverview? overview;
    List<Map<String, dynamic>> continueWatching = [];
    Object? firstError;
    try {
      overview = await _miscRepository.getStatsOverview();
    } catch (e) {
      debugPrint('[STATS] overview failed: $e');
      firstError ??= e;
    }
    try {
      continueWatching = await _miscRepository.getContinueWatching();
    } catch (e) {
      debugPrint('[STATS] continue-watching failed: $e');
      firstError ??= e;
    }
    debugPrint(
      '[STATS] loaded courses=${overview?.totalCourses} '
      'continue=${continueWatching.length}',
    );
    if (overview == null && continueWatching.isEmpty && firstError != null) {
      emit(StatsFailure(firstError.toString()));
      return;
    }
    emit(
      StatsLoaded(
        overview ??
            StatsOverview(totalUsers: 0, totalCourses: 0, totalWatchTime: 0),
        continueWatching,
      ),
    );
  }
}
