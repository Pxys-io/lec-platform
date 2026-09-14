import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/course.dart';
import '../../repositories/course_repository.dart';

abstract class CourseState extends Equatable {
  const CourseState();
  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}
class CourseLoading extends CourseState {}
class CourseLoaded extends CourseState {
  final List<Course> courses;
  final Set<String> ownedIds;
  const CourseLoaded(this.courses, {this.ownedIds = const {}});
  @override
  List<Object?> get props => [courses, ownedIds];
}
class CourseFailure extends CourseState {
  final String message;
  const CourseFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class CourseCubit extends Cubit<CourseState> {
  final CourseRepository _courseRepository;

  CourseCubit(this._courseRepository) : super(CourseInitial());

  Future<void> loadCourses() async {
    emit(CourseLoading());
    try {
      final courses = await _courseRepository.getCourses();
      Set<String> owned = {};
      try {
        owned = (await _courseRepository.getMyCourses()).map((c) => c.id).toSet();
      } catch (_) {
        // Ownership is a progressive enhancement; course list still works.
      }
      emit(CourseLoaded(courses, ownedIds: owned));
    } catch (e) {
      emit(CourseFailure(e.toString()));
    }
  }
}
