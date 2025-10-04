import 'dart:io';

class QuestionMetadataModel {
  final File questionFile;
  final File answerFile;
  final String baseName;

  String? stream;
  String? level;
  String? topic;
  String? subtopic;
  String? language;
  String? chapter;
  String? type;
  List<String> tags; // New field for multiple tags

  // PDF file references (will be populated after conversion)
  File? questionPdfFile;
  File? answerPdfFile;

  QuestionMetadataModel({
    required this.questionFile,
    required this.answerFile,
    required this.baseName,
    this.stream,
    this.level,
    this.topic,
    this.subtopic,
    this.language,
    this.chapter,
    this.type,
    List<String>? tags,
    this.questionPdfFile,
    this.answerPdfFile,
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

  bool get hasPdfFiles => questionPdfFile != null && answerPdfFile != null;

  bool get hasTags => tags.isNotEmpty;

  String get tagsAsString => tags.join(', ');

  Map<String, dynamic> get metadata {
    return {
      'stream': stream,
      'level': level,
      'topic': topic,
      'subtopic': subtopic,
      'language': language,
      'chapter': chapter,
      'type': type,
      'tags': tags,
    };
  }

  void copyMetadataFrom(QuestionMetadataModel other) {
    stream = other.stream;
    level = other.level;
    topic = other.topic;
    subtopic = other.subtopic;
    language = other.language;
    chapter = other.chapter;
    type = other.type;
    tags = List.from(other.tags); // Create a copy of the tags list
  }

  void setPdfFiles(File? questionPdf, File? answerPdf) {
    questionPdfFile = questionPdf;
    answerPdfFile = answerPdf;
  }

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

  // Filter tags based on a search query
  List<String> searchTags(String query) {
    if (query.isEmpty) return tags;
    return tags
        .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  QuestionMetadataModel copyWith({
    String? stream,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
    List<String>? tags,
    File? questionPdfFile,
    File? answerPdfFile,
  }) {
    return QuestionMetadataModel(
      questionFile: questionFile,
      answerFile: answerFile,
      baseName: baseName,
      stream: stream ?? this.stream,
      level: level ?? this.level,
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      language: language ?? this.language,
      chapter: chapter ?? this.chapter,
      type: type ?? this.type,
      tags: tags ?? List.from(this.tags),
      questionPdfFile: questionPdfFile ?? this.questionPdfFile,
      answerPdfFile: answerPdfFile ?? this.answerPdfFile,
    );
  }

  @override
  String toString() {
    return 'QuestionMetadataModel(baseName: $baseName, stream: $stream, level: $level, topic: $topic, tags: ${tags.length}, hasPdfs: $hasPdfFiles)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QuestionMetadataModel) return false;

    return baseName == other.baseName &&
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
      baseName,
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
