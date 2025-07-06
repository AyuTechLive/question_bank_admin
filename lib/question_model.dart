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
    );
  }
}
