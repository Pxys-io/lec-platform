import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/lesson.dart';
import '../../repositories/course_repository.dart';

abstract class LessonState extends Equatable {
  const LessonState();
  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}
class LessonLoading extends LessonState {}
class LessonLoaded extends LessonState {
  final List<Lesson> lessons;
  const LessonLoaded(this.lessons);
  @override
  List<Object?> get props => [lessons];
}
class LessonFailure extends LessonState {
  final String message;
  const LessonFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class LessonCubit extends Cubit<LessonState> {
  final CourseRepository _courseRepository;

  LessonCubit(this._courseRepository) : super(LessonInitial());

  Future<void> loadLessons(String courseId) async {
    emit(LessonLoading());
    try {
      final lessons = await _courseRepository.getCourseLessons(courseId);
      emit(LessonLoaded(lessons));
    } catch (e) {
      emit(LessonFailure(e.toString()));
    }
  }
}
