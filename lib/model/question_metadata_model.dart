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
    this.questionPdfFile,
    this.answerPdfFile,
  });

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

  Map<String, String?> get metadata {
    return {
      'stream': stream,
      'level': level,
      'topic': topic,
      'subtopic': subtopic,
      'language': language,
      'chapter': chapter,
      'type': type,
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
  }

  void setPdfFiles(File? questionPdf, File? answerPdf) {
    questionPdfFile = questionPdf;
    answerPdfFile = answerPdf;
  }

  QuestionMetadataModel copyWith({
    String? stream,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
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
      questionPdfFile: questionPdfFile ?? this.questionPdfFile,
      answerPdfFile: answerPdfFile ?? this.answerPdfFile,
    );
  }

  @override
  String toString() {
    return 'QuestionMetadataModel(baseName: $baseName, stream: $stream, level: $level, topic: $topic, hasPdfs: $hasPdfFiles)';
  }
}
