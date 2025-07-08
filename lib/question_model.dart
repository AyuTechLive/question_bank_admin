class QuestionModel {
  String? questionId;
  String stream;
  String level;
  String topic;
  String subtopic;
  String language;
  String chapter;
  String type;

  // Original file paths (DOC/DOCX files)
  String? questionFileUrl;
  String? answerFileUrl;
  String? questionFilePath;
  String? answerFilePath;

  // PDF file paths (converted versions)
  String? questionPdfUrl;
  String? answerPdfUrl;
  String? questionPdfPath;
  String? answerPdfPath;

  DateTime? uploadedAt;

  // Additional metadata for better tracking
  String? originalQuestionFileName;
  String? originalAnswerFileName;
  String? questionPdfFileName;
  String? answerPdfFileName;
  int? questionFileSize;
  int? answerFileSize;
  int? questionPdfSize;
  int? answerPdfSize;

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
    this.questionPdfUrl,
    this.answerPdfUrl,
    this.questionPdfPath,
    this.answerPdfPath,
    this.uploadedAt,
    this.originalQuestionFileName,
    this.originalAnswerFileName,
    this.questionPdfFileName,
    this.answerPdfFileName,
    this.questionFileSize,
    this.answerFileSize,
    this.questionPdfSize,
    this.answerPdfSize,
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
      'questionPdfUrl': questionPdfUrl,
      'answerPdfUrl': answerPdfUrl,
      'uploadedAt': uploadedAt ?? DateTime.now(),
      'originalQuestionFileName': originalQuestionFileName,
      'originalAnswerFileName': originalAnswerFileName,
      'questionPdfFileName': questionPdfFileName,
      'answerPdfFileName': answerPdfFileName,
      'questionFileSize': questionFileSize,
      'answerFileSize': answerFileSize,
      'questionPdfSize': questionPdfSize,
      'answerPdfSize': answerPdfSize,
      'createdAt': DateTime.now(),
      'version': 2, // Updated version for PDF support
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
      questionPdfUrl: map['questionPdfUrl'],
      answerPdfUrl: map['answerPdfUrl'],
      uploadedAt: map['uploadedAt']?.toDate(),
      originalQuestionFileName: map['originalQuestionFileName'],
      originalAnswerFileName: map['originalAnswerFileName'],
      questionPdfFileName: map['questionPdfFileName'],
      answerPdfFileName: map['answerPdfFileName'],
      questionFileSize: map['questionFileSize'],
      answerFileSize: map['answerFileSize'],
      questionPdfSize: map['questionPdfSize'],
      answerPdfSize: map['answerPdfSize'],
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
    String? questionPdfPath,
    String? answerPdfPath,
    String? originalQuestionFileName,
    String? originalAnswerFileName,
    String? questionPdfFileName,
    String? answerPdfFileName,
    int? questionFileSize,
    int? answerFileSize,
    int? questionPdfSize,
    int? answerPdfSize,
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
      questionPdfPath: questionPdfPath,
      answerPdfPath: answerPdfPath,
      originalQuestionFileName: originalQuestionFileName,
      originalAnswerFileName: originalAnswerFileName,
      questionPdfFileName: questionPdfFileName,
      answerPdfFileName: answerPdfFileName,
      questionFileSize: questionFileSize,
      answerFileSize: answerFileSize,
      questionPdfSize: questionPdfSize,
      answerPdfSize: answerPdfSize,
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
    String? questionPdfUrl,
    String? answerPdfUrl,
    String? questionPdfPath,
    String? answerPdfPath,
    DateTime? uploadedAt,
    String? originalQuestionFileName,
    String? originalAnswerFileName,
    String? questionPdfFileName,
    String? answerPdfFileName,
    int? questionFileSize,
    int? answerFileSize,
    int? questionPdfSize,
    int? answerPdfSize,
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
      questionPdfUrl: questionPdfUrl ?? this.questionPdfUrl,
      answerPdfUrl: answerPdfUrl ?? this.answerPdfUrl,
      questionPdfPath: questionPdfPath ?? this.questionPdfPath,
      answerPdfPath: answerPdfPath ?? this.answerPdfPath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      originalQuestionFileName:
          originalQuestionFileName ?? this.originalQuestionFileName,
      originalAnswerFileName:
          originalAnswerFileName ?? this.originalAnswerFileName,
      questionPdfFileName: questionPdfFileName ?? this.questionPdfFileName,
      answerPdfFileName: answerPdfFileName ?? this.answerPdfFileName,
      questionFileSize: questionFileSize ?? this.questionFileSize,
      answerFileSize: answerFileSize ?? this.answerFileSize,
      questionPdfSize: questionPdfSize ?? this.questionPdfSize,
      answerPdfSize: answerPdfSize ?? this.answerPdfSize,
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
