class QuestionModel {
  String? questionId;
  String? stream;
  String? level;
  String? topic;
  String? subtopic;
  String? language;
  String? chapter;
  String? type;
  List<String> tags; // New field for tags

  String? questionFilePath;
  String? answerFilePath;
  String? questionFileUrl;
  String? answerFileUrl;

  // PDF support
  String? questionPdfPath;
  String? answerPdfPath;
  String? questionPdfUrl;
  String? answerPdfUrl;
  String? questionPdfFileName;
  String? answerPdfFileName;
  int? questionPdfSize;
  int? answerPdfSize;

  // File metadata
  String? originalQuestionFileName;
  String? originalAnswerFileName;
  int? questionFileSize;
  int? answerFileSize;

  DateTime? uploadedAt;
  DateTime? createdAt;
  DateTime? updatedAt;

  QuestionModel({
    this.questionId,
    this.stream,
    this.level,
    this.topic,
    this.subtopic,
    this.language,
    this.chapter,
    this.type,
    List<String>? tags,
    this.questionFilePath,
    this.answerFilePath,
    this.questionFileUrl,
    this.answerFileUrl,
    this.questionPdfPath,
    this.answerPdfPath,
    this.questionPdfUrl,
    this.answerPdfUrl,
    this.questionPdfFileName,
    this.answerPdfFileName,
    this.questionPdfSize,
    this.answerPdfSize,
    this.originalQuestionFileName,
    this.originalAnswerFileName,
    this.questionFileSize,
    this.answerFileSize,
    this.uploadedAt,
    this.createdAt,
    this.updatedAt,
  }) : tags = tags ?? [];

  bool get isValid {
    return stream != null &&
        level != null &&
        topic != null &&
        subtopic != null &&
        language != null &&
        chapter != null &&
        type != null;
  }

  bool get hasPdfFiles => questionPdfUrl != null && answerPdfUrl != null;
  bool get hasTags => tags.isNotEmpty;
  String get tagsAsString => tags.join(', ');

  // Tag management methods
  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
  }

  void clearTags() {
    tags.clear();
  }

  void setTags(List<String> newTags) {
    tags = List.from(newTags);
  }

  bool hasTag(String tag) {
    return tags.contains(tag);
  }

  void toggleTag(String tag) {
    if (hasTag(tag)) {
      removeTag(tag);
    } else {
      addTag(tag);
    }
  }

  // Search tags
  List<String> searchTags(String query) {
    if (query.isEmpty) return tags;
    return tags
        .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Check if question matches any of the provided tags
  bool matchesAnyTag(List<String> searchTags) {
    if (searchTags.isEmpty) return true;
    return searchTags.any((searchTag) => tags.contains(searchTag));
  }

  // Check if question matches all of the provided tags
  bool matchesAllTags(List<String> searchTags) {
    if (searchTags.isEmpty) return true;
    return searchTags.every((searchTag) => tags.contains(searchTag));
  }

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
      'tags': tags, // Store as array in Firestore
      'questionFilePath': questionFilePath,
      'answerFilePath': answerFilePath,
      'questionFileUrl': questionFileUrl,
      'answerFileUrl': answerFileUrl,
      'questionPdfPath': questionPdfPath,
      'answerPdfPath': answerPdfPath,
      'questionPdfUrl': questionPdfUrl,
      'answerPdfUrl': answerPdfUrl,
      'questionPdfFileName': questionPdfFileName,
      'answerPdfFileName': answerPdfFileName,
      'questionPdfSize': questionPdfSize,
      'answerPdfSize': answerPdfSize,
      'originalQuestionFileName': originalQuestionFileName,
      'originalAnswerFileName': originalAnswerFileName,
      'questionFileSize': questionFileSize,
      'answerFileSize': answerFileSize,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map, [String? id]) {
    // Handle tags - could be stored as array or comma-separated string
    List<String> tagsList = [];
    final tagsData = map['tags'];
    if (tagsData != null) {
      if (tagsData is List) {
        tagsList = List<String>.from(tagsData);
      } else if (tagsData is String) {
        // Support legacy comma-separated format
        tagsList = tagsData
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }

    return QuestionModel(
      questionId: id ?? map['questionId'],
      stream: map['stream'],
      level: map['level'],
      topic: map['topic'],
      subtopic: map['subtopic'],
      language: map['language'],
      chapter: map['chapter'],
      type: map['type'],
      tags: tagsList,
      questionFilePath: map['questionFilePath'],
      answerFilePath: map['answerFilePath'],
      questionFileUrl: map['questionFileUrl'],
      answerFileUrl: map['answerFileUrl'],
      questionPdfPath: map['questionPdfPath'],
      answerPdfPath: map['answerPdfPath'],
      questionPdfUrl: map['questionPdfUrl'],
      answerPdfUrl: map['answerPdfUrl'],
      questionPdfFileName: map['questionPdfFileName'],
      answerPdfFileName: map['answerPdfFileName'],
      questionPdfSize: map['questionPdfSize']?.toInt(),
      answerPdfSize: map['answerPdfSize']?.toInt(),
      originalQuestionFileName: map['originalQuestionFileName'],
      originalAnswerFileName: map['originalAnswerFileName'],
      questionFileSize: map['questionFileSize']?.toInt(),
      answerFileSize: map['answerFileSize']?.toInt(),
      uploadedAt:
          map['uploadedAt'] != null ? DateTime.parse(map['uploadedAt']) : null,
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  QuestionModel copyWith({
    String? questionId,
    String? stream,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
    List<String>? tags,
    String? questionFilePath,
    String? answerFilePath,
    String? questionFileUrl,
    String? answerFileUrl,
    String? questionPdfPath,
    String? answerPdfPath,
    String? questionPdfUrl,
    String? answerPdfUrl,
    String? questionPdfFileName,
    String? answerPdfFileName,
    int? questionPdfSize,
    int? answerPdfSize,
    String? originalQuestionFileName,
    String? originalAnswerFileName,
    int? questionFileSize,
    int? answerFileSize,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      tags: tags ?? List.from(this.tags),
      questionFilePath: questionFilePath ?? this.questionFilePath,
      answerFilePath: answerFilePath ?? this.answerFilePath,
      questionFileUrl: questionFileUrl ?? this.questionFileUrl,
      answerFileUrl: answerFileUrl ?? this.answerFileUrl,
      questionPdfPath: questionPdfPath ?? this.questionPdfPath,
      answerPdfPath: answerPdfPath ?? this.answerPdfPath,
      questionPdfUrl: questionPdfUrl ?? this.questionPdfUrl,
      answerPdfUrl: answerPdfUrl ?? this.answerPdfUrl,
      questionPdfFileName: questionPdfFileName ?? this.questionPdfFileName,
      answerPdfFileName: answerPdfFileName ?? this.answerPdfFileName,
      questionPdfSize: questionPdfSize ?? this.questionPdfSize,
      answerPdfSize: answerPdfSize ?? this.answerPdfSize,
      originalQuestionFileName:
          originalQuestionFileName ?? this.originalQuestionFileName,
      originalAnswerFileName:
          originalAnswerFileName ?? this.originalAnswerFileName,
      questionFileSize: questionFileSize ?? this.questionFileSize,
      answerFileSize: answerFileSize ?? this.answerFileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'QuestionModel(questionId: $questionId, stream: $stream, topic: $topic, tags: ${tags.length}, hasPdfs: $hasPdfFiles)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuestionModel) return false;

    return questionId == other.questionId &&
        stream == other.stream &&
        level == other.level &&
        topic == other.topic &&
        subtopic == other.subtopic &&
        language == other.language &&
        chapter == other.chapter &&
        type == other.type &&
        _listEquals(tags, other.tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      questionId,
      stream,
      level,
      topic,
      subtopic,
      language,
      chapter,
      type,
      Object.hashAll(tags),
    );
  }

  // Helper method to compare lists
  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}
