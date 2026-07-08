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
  final String? quizId;
  final String? qbankId;
  final String type;
  final String text;
  final List<String> options;
  final String correctAnswer;
  final String? explanation;
  final List<String> tags;
  final double points;
  final int order;

  Question({
    required this.id,
    this.quizId,
    this.qbankId,
    required this.type,
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.tags = const [],
    required this.points,
    required this.order,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      quizId: json['quiz_id'],
      qbankId: json['qbank_id'],
      type: json['type'],
      text: json['question'] ?? '',
      options: json['options'] != null ? List<String>.from(json['options']) : [],
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'],
      tags: List<String>.from(json['tags'] ?? []),
      points: (json['points'] as num).toDouble(),
      order: json['order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_id': quizId,
      'qbank_id': qbankId,
      'type': type,
      'question': text,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'tags': tags,
      'points': points,
      'order': order,
    };
  }
}
