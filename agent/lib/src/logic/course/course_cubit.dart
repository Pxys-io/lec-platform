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
  const CourseLoaded(this.courses);
  @override
  List<Object?> get props => [courses];
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
      emit(CourseLoaded(courses));
    } catch (e) {
      emit(CourseFailure(e.toString()));
    }
  }
}
