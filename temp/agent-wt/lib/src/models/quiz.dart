class Quiz {
  final String id;
  final String lessonId;
  final String title;
  final String? description;
  final double passingScore;
  final int? timeLimit;
  final List<Question> questions;
  final DateTime createdAt;

  Quiz({
    required this.id,
    required this.lessonId,
    required this.title,
    this.description,
    required this.passingScore,
    this.timeLimit,
    this.questions = const [],
    required this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      lessonId: json['lesson_id'],
      title: json['title'],
      description: json['description'],
      passingScore: (json['passing_score'] as num).toDouble(),
      timeLimit: json['time_limit'],
      questions: json['questions'] != null 
          ? (json['questions'] as List).map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map))).toList() 
          : [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'title': title,
      'description': description,
      'passing_score': passingScore,
      'time_limit': timeLimit,
      'questions': questions.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Question {
  final String id;
  final String quizId;
  final String type;
  final String text;
  final Map<String, String> options;
  final String correctOption;
  final String explanation;
  final double points;
  final int order;

  Question({
    required this.id,
    required this.quizId,
    required this.type,
    required this.text,
    required this.options,
    required this.correctOption,
    required this.explanation,
    required this.points,
    required this.order,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      quizId: json['quiz_id'],
      type: json['type'],
      text: json['text'] ?? json['question'] ?? '',
      options: json['options'] != null ? Map<String, String>.from(json['options']) : {},
      correctOption: json['correct_option'] ?? json['correct_answer'] ?? '',
      explanation: json['explanation'] ?? '',
      points: (json['points'] as num).toDouble(),
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'type': type,
      'text': text,
      'options': options,
      'correct_option': correctOption,
      'explanation': explanation,
      'points': points,
      'order': order,
    };
  }
}
