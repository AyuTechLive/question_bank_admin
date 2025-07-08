class QuestionModel {
  String? questionId;
  String stream;
  String level;
  String topic;
  String subtopic;
  String language;
  String chapter;
  String type;
  String? questionFileUrl;
  String? answerFileUrl;
  String? questionFilePath;
  String? answerFilePath;
  DateTime? uploadedAt;

  // Additional metadata for better tracking
  String? originalQuestionFileName;
  String? originalAnswerFileName;
  int? questionFileSize;
  int? answerFileSize;

  QuestionModel({
    this.questionId,
    required this.stream,
    required this.level,
    required this.topic,
    required this.subtopic,
    required this.language,
    required this.chapter,
    required this.type,
    this.questionFileUrl,
    this.answerFileUrl,
    this.questionFilePath,
    this.answerFilePath,
    this.uploadedAt,
    this.originalQuestionFileName,
    this.originalAnswerFileName,
    this.questionFileSize,
    this.answerFileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'stream': stream,
      'level': level,
      'topic': topic,
      'subtopic': subtopic,
      'language': language,
      'chapter': chapter,
      'type': type,
      'questionFileUrl': questionFileUrl,
      'answerFileUrl': answerFileUrl,
      'uploadedAt': uploadedAt ?? DateTime.now(),
      'originalQuestionFileName': originalQuestionFileName,
      'originalAnswerFileName': originalAnswerFileName,
      'questionFileSize': questionFileSize,
      'answerFileSize': answerFileSize,
      'createdAt': DateTime.now(),
      'version': 1, // For future compatibility
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map, String docId) {
    return QuestionModel(
      questionId: docId,
      stream: map['stream'] ?? '',
      level: map['level'] ?? '',
      topic: map['topic'] ?? '',
      subtopic: map['subtopic'] ?? '',
      language: map['language'] ?? '',
      chapter: map['chapter'] ?? '',
      type: map['type'] ?? '',
      questionFileUrl: map['questionFileUrl'],
      answerFileUrl: map['answerFileUrl'],
      uploadedAt: map['uploadedAt']?.toDate(),
      originalQuestionFileName: map['originalQuestionFileName'],
      originalAnswerFileName: map['originalAnswerFileName'],
      questionFileSize: map['questionFileSize'],
      answerFileSize: map['answerFileSize'],
    );
  }

  // Create from local database question pair and metadata
  factory QuestionModel.fromLocalData({
    required String stream,
    required String level,
    required String topic,
    required String subtopic,
    required String language,
    required String chapter,
    required String type,
    required String questionFilePath,
    required String answerFilePath,
    String? originalQuestionFileName,
    String? originalAnswerFileName,
    int? questionFileSize,
    int? answerFileSize,
  }) {
    return QuestionModel(
      stream: stream,
      level: level,
      topic: topic,
      subtopic: subtopic,
      language: language,
      chapter: chapter,
      type: type,
      questionFilePath: questionFilePath,
      answerFilePath: answerFilePath,
      originalQuestionFileName: originalQuestionFileName,
      originalAnswerFileName: originalAnswerFileName,
      questionFileSize: questionFileSize,
      answerFileSize: answerFileSize,
    );
  }

  // Validation
  bool get isValid {
    return stream.isNotEmpty &&
        level.isNotEmpty &&
        topic.isNotEmpty &&
        subtopic.isNotEmpty &&
        language.isNotEmpty &&
        chapter.isNotEmpty &&
        type.isNotEmpty &&
        (questionFilePath != null || questionFileUrl != null) &&
        (answerFilePath != null || answerFileUrl != null);
  }

  // Copy constructor for easy cloning
  QuestionModel copyWith({
    String? questionId,
    String? stream,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
    String? questionFileUrl,
    String? answerFileUrl,
    String? questionFilePath,
    String? answerFilePath,
    DateTime? uploadedAt,
    String? originalQuestionFileName,
    String? originalAnswerFileName,
    int? questionFileSize,
    int? answerFileSize,
  }) {
    return QuestionModel(
      questionId: questionId ?? this.questionId,
      stream: stream ?? this.stream,
      level: level ?? this.level,
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      language: language ?? this.language,
      chapter: chapter ?? this.chapter,
      type: type ?? this.type,
      questionFileUrl: questionFileUrl ?? this.questionFileUrl,
      answerFileUrl: answerFileUrl ?? this.answerFileUrl,
      questionFilePath: questionFilePath ?? this.questionFilePath,
      answerFilePath: answerFilePath ?? this.answerFilePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      originalQuestionFileName:
          originalQuestionFileName ?? this.originalQuestionFileName,
      originalAnswerFileName:
          originalAnswerFileName ?? this.originalAnswerFileName,
      questionFileSize: questionFileSize ?? this.questionFileSize,
      answerFileSize: answerFileSize ?? this.answerFileSize,
    );
  }

  @override
  String toString() {
    return 'QuestionModel(questionId: $questionId, stream: $stream, level: $level, topic: $topic, subtopic: $subtopic, language: $language, chapter: $chapter, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QuestionModel &&
        other.questionId == questionId &&
        other.stream == stream &&
        other.level == level &&
        other.topic == topic &&
        other.subtopic == subtopic &&
        other.language == language &&
        other.chapter == chapter &&
        other.type == type;
  }

  @override
  int get hashCode {
    return questionId.hashCode ^
        stream.hashCode ^
        level.hashCode ^
        topic.hashCode ^
        subtopic.hashCode ^
        language.hashCode ^
        chapter.hashCode ^
        type.hashCode;
  }
}
