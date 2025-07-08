import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:question_bank/question_model.dart';
import 'package:question_bank/service/doc_converter.dart';
import 'package:question_bank/service/local_db.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService();

  /// Get the correct MIME type for a file based on its extension
  String _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      case '.gnm':
        return 'application/x-gnumeric';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> uploadQuestion(QuestionModel question) async {
    try {
      print('Starting upload for question with PDF support...');

      // Validate input files exist
      if (question.questionFilePath == null ||
          question.answerFilePath == null) {
        throw Exception('Question or answer file path is null');
      }

      final questionFile = File(question.questionFilePath!);
      final answerFile = File(question.answerFilePath!);

      if (!await questionFile.exists()) {
        throw Exception(
            'Question file does not exist: ${question.questionFilePath}');
      }

      if (!await answerFile.exists()) {
        throw Exception(
            'Answer file does not exist: ${question.answerFilePath}');
      }

      print('Files exist, proceeding with upload...');

      // Get file information for storage
      final questionSize = await questionFile.length();
      final answerSize = await answerFile.length();
      final questionName = path.basename(question.questionFilePath!);
      final answerName = path.basename(question.answerFilePath!);

      // Generate unique question ID first
      final docRef = _firestore
          .collection('data')
          .doc(question.stream)
          .collection('questions')
          .doc();
      question.questionId = docRef.id;

      print('Generated question ID: ${question.questionId}');

      // Convert files to PDF if needed and cache them
      String? questionPdfPath;
      String? answerPdfPath;

      try {
        // Check for cached PDF first
        questionPdfPath =
            await _localDb.getCachedPdfPath(question.questionFilePath!);
        if (questionPdfPath == null) {
          // Convert and cache
          questionPdfPath = await DocumentConverterService.convertToPdf(
              question.questionFilePath!);
          if (questionPdfPath != null) {
            await _localDb.cachePdfConversion(
                question.questionFilePath!, questionPdfPath);
          }
        }

        // Same for answer file
        answerPdfPath =
            await _localDb.getCachedPdfPath(question.answerFilePath!);
        if (answerPdfPath == null) {
          answerPdfPath = await DocumentConverterService.convertToPdf(
              question.answerFilePath!);
          if (answerPdfPath != null) {
            await _localDb.cachePdfConversion(
                question.answerFilePath!, answerPdfPath);
          }
        }

        print(
            'PDF conversion completed - Question: ${questionPdfPath != null}, Answer: ${answerPdfPath != null}');
      } catch (e) {
        print('PDF conversion failed: $e');
        // Continue without PDFs
      }

      // Upload original question file with correct MIME type
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/original/${question.stream}/$questionFileName');

      print('Uploading original question file: $questionFileName');

      try {
        final questionMimeType = _getMimeType(question.questionFilePath!);
        print('Question file MIME type: $questionMimeType');

        final questionUploadTask = questionRef.putFile(
          questionFile,
          SettableMetadata(contentType: questionMimeType),
        );
        final questionTaskSnapshot = await questionUploadTask;
        question.questionFileUrl =
            await questionTaskSnapshot.ref.getDownloadURL();
        print(
            'Original question file uploaded successfully: ${question.questionFileUrl}');
      } catch (e) {
        print('Error uploading original question file: $e');
        throw Exception('Failed to upload original question file: $e');
      }

      // Upload original answer file with correct MIME type
      String answerFileName =
          '${question.questionId}_answer${path.extension(question.answerFilePath!)}';
      final answerRef = _storage
          .ref()
          .child('answers/original/${question.stream}/$answerFileName');

      print('Uploading original answer file: $answerFileName');

      try {
        final answerMimeType = _getMimeType(question.answerFilePath!);
        print('Answer file MIME type: $answerMimeType');

        final answerUploadTask = answerRef.putFile(
          answerFile,
          SettableMetadata(contentType: answerMimeType),
        );
        final answerTaskSnapshot = await answerUploadTask;
        question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();
        print(
            'Original answer file uploaded successfully: ${question.answerFileUrl}');
      } catch (e) {
        print('Error uploading original answer file: $e');
        throw Exception('Failed to upload original answer file: $e');
      }

      // Upload PDF files if available
      if (questionPdfPath != null && File(questionPdfPath).existsSync()) {
        try {
          String questionPdfFileName = '${question.questionId}_question.pdf';
          final questionPdfRef = _storage
              .ref()
              .child('questions/pdf/${question.stream}/$questionPdfFileName');

          print('Uploading question PDF: $questionPdfFileName');

          // Set correct MIME type for PDF
          final questionPdfUploadTask = questionPdfRef.putFile(
            File(questionPdfPath),
            SettableMetadata(contentType: 'application/pdf'),
          );
          final questionPdfTaskSnapshot = await questionPdfUploadTask;
          question.questionPdfUrl =
              await questionPdfTaskSnapshot.ref.getDownloadURL();

          // Set PDF metadata
          question.questionPdfPath = questionPdfPath;
          question.questionPdfFileName = questionPdfFileName;
          question.questionPdfSize = await File(questionPdfPath).length();

          print(
              'Question PDF uploaded successfully: ${question.questionPdfUrl}');
        } catch (e) {
          print('Error uploading question PDF: $e');
          // Continue without PDF
        }
      }

      if (answerPdfPath != null && File(answerPdfPath).existsSync()) {
        try {
          String answerPdfFileName = '${question.questionId}_answer.pdf';
          final answerPdfRef = _storage
              .ref()
              .child('answers/pdf/${question.stream}/$answerPdfFileName');

          print('Uploading answer PDF: $answerPdfFileName');

          // Set correct MIME type for PDF
          final answerPdfUploadTask = answerPdfRef.putFile(
            File(answerPdfPath),
            SettableMetadata(contentType: 'application/pdf'),
          );
          final answerPdfTaskSnapshot = await answerPdfUploadTask;
          question.answerPdfUrl =
              await answerPdfTaskSnapshot.ref.getDownloadURL();

          // Set PDF metadata
          question.answerPdfPath = answerPdfPath;
          question.answerPdfFileName = answerPdfFileName;
          question.answerPdfSize = await File(answerPdfPath).length();

          print('Answer PDF uploaded successfully: ${question.answerPdfUrl}');
        } catch (e) {
          print('Error uploading answer PDF: $e');
          // Continue without PDF
        }
      }

      // Set upload timestamp and file information
      question.uploadedAt = DateTime.now();
      question.originalQuestionFileName = questionName;
      question.originalAnswerFileName = answerName;
      question.questionFileSize = questionSize;
      question.answerFileSize = answerSize;

      // Save to Firestore
      print('Saving to Firestore...');
      try {
        await docRef.set(question.toMap());
        print(
            'Successfully saved to Firestore with ID: ${question.questionId}');
      } catch (e) {
        print('Error saving to Firestore: $e');
        // Try to cleanup uploaded files if Firestore save fails
        try {
          await questionRef.delete();
          await answerRef.delete();
          if (question.questionPdfUrl != null) {
            await _storage.refFromURL(question.questionPdfUrl!).delete();
          }
          if (question.answerPdfUrl != null) {
            await _storage.refFromURL(question.answerPdfUrl!).delete();
          }
        } catch (cleanupError) {
          print('Error during cleanup: $cleanupError');
        }
        throw Exception('Failed to save to Firestore: $e');
      }

      print('Question upload completed successfully with PDF support');
    } catch (e) {
      print('Failed to upload question: $e');
      debugPrint('Failed to upload question: $e');
      rethrow;
    }
  }

  // Upload with progress callback (enhanced with PDF support)
  Future<void> uploadQuestionWithProgress(
    QuestionModel question,
    Function(double)? onProgress,
  ) async {
    try {
      print('Starting upload with progress tracking and PDF support...');

      // Validate input files exist
      if (question.questionFilePath == null ||
          question.answerFilePath == null) {
        throw Exception('Question or answer file path is null');
      }

      final questionFile = File(question.questionFilePath!);
      final answerFile = File(question.answerFilePath!);

      if (!await questionFile.exists()) {
        throw Exception(
            'Question file does not exist: ${question.questionFilePath}');
      }

      if (!await answerFile.exists()) {
        throw Exception(
            'Answer file does not exist: ${question.answerFilePath}');
      }

      // Generate unique question ID
      final docRef = _firestore
          .collection('data')
          .doc(question.stream)
          .collection('questions')
          .doc();
      question.questionId = docRef.id;

      double totalProgress = 0.0;
      final totalFiles = 2; // Original files
      int currentFileIndex = 0;

      // Update progress helper
      void updateProgress(double fileProgress) {
        final overallProgress = (currentFileIndex + fileProgress) / totalFiles;
        if (onProgress != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onProgress(overallProgress *
                0.8); // Reserve 20% for PDF conversion and Firestore save
          });
        }
      }

      // Convert to PDF in background while uploading originals
      String? questionPdfPath;
      String? answerPdfPath;

      // Start PDF conversion asynchronously
      final pdfConversionFuture = Future.wait([
        _convertAndCachePdf(question.questionFilePath!),
        _convertAndCachePdf(question.answerFilePath!),
      ]);

      // Upload original question file with correct MIME type
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/original/${question.stream}/$questionFileName');

      final questionMimeType = _getMimeType(question.questionFilePath!);
      print('Question file MIME type: $questionMimeType');

      final questionUploadTask = questionRef.putFile(
        questionFile,
        SettableMetadata(contentType: questionMimeType),
      );

      questionUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            updateProgress(progress);
          }
        },
        onError: (error) {
          debugPrint('Question upload progress error: $error');
        },
      );

      final questionTaskSnapshot = await questionUploadTask;
      question.questionFileUrl =
          await questionTaskSnapshot.ref.getDownloadURL();
      currentFileIndex++;

      // Upload original answer file with correct MIME type
      String answerFileName =
          '${question.questionId}_answer${path.extension(question.answerFilePath!)}';
      final answerRef = _storage
          .ref()
          .child('answers/original/${question.stream}/$answerFileName');

      final answerMimeType = _getMimeType(question.answerFilePath!);
      print('Answer file MIME type: $answerMimeType');

      final answerUploadTask = answerRef.putFile(
        answerFile,
        SettableMetadata(contentType: answerMimeType),
      );

      answerUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            updateProgress(progress);
          }
        },
        onError: (error) {
          debugPrint('Answer upload progress error: $error');
        },
      );

      final answerTaskSnapshot = await answerUploadTask;
      question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();

      // Update progress to 80%
      if (onProgress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onProgress(0.8);
        });
      }

      // Wait for PDF conversion to complete
      try {
        final pdfResults = await pdfConversionFuture;
        questionPdfPath = pdfResults[0];
        answerPdfPath = pdfResults[1];

        // Upload PDFs if available
        if (questionPdfPath != null && File(questionPdfPath).existsSync()) {
          await _uploadPdfFile(
            File(questionPdfPath),
            'questions/pdf/${question.stream}/${question.questionId}_question.pdf',
            question,
            true, // isQuestion
          );
        }

        if (answerPdfPath != null && File(answerPdfPath).existsSync()) {
          await _uploadPdfFile(
            File(answerPdfPath),
            'answers/pdf/${question.stream}/${question.questionId}_answer.pdf',
            question,
            false, // isAnswer
          );
        }
      } catch (e) {
        print('PDF conversion/upload failed: $e');
        // Continue without PDFs
      }

      // Update progress to 90%
      if (onProgress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onProgress(0.9);
        });
      }

      // Set upload timestamp and file information
      question.uploadedAt = DateTime.now();
      question.originalQuestionFileName =
          path.basename(question.questionFilePath!);
      question.originalAnswerFileName = path.basename(question.answerFilePath!);
      question.questionFileSize =
          await File(question.questionFilePath!).length();
      question.answerFileSize = await File(question.answerFilePath!).length();

      // Save to Firestore
      await docRef.set(question.toMap());

      // Final progress callback
      if (onProgress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onProgress(1.0);
        });
      }

      print(
          'Question upload with progress and PDF support completed successfully');
    } catch (e) {
      debugPrint('Failed to upload question with progress: $e');
      rethrow;
    }
  }

  Future<String?> _convertAndCachePdf(String originalFilePath) async {
    try {
      // Check for cached PDF first
      String? pdfPath = await _localDb.getCachedPdfPath(originalFilePath);
      if (pdfPath != null) {
        return pdfPath;
      }

      // Convert and cache
      pdfPath = await DocumentConverterService.convertToPdf(originalFilePath);
      if (pdfPath != null) {
        await _localDb.cachePdfConversion(originalFilePath, pdfPath);
      }
      return pdfPath;
    } catch (e) {
      debugPrint('PDF conversion failed for $originalFilePath: $e');
      return null;
    }
  }

  Future<void> _uploadPdfFile(File pdfFile, String storagePath,
      QuestionModel question, bool isQuestion) async {
    try {
      final pdfRef = _storage.ref().child(storagePath);
      // Always set PDF MIME type explicitly
      final pdfUploadTask = pdfRef.putFile(
        pdfFile,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final pdfTaskSnapshot = await pdfUploadTask;
      final downloadUrl = await pdfTaskSnapshot.ref.getDownloadURL();

      if (isQuestion) {
        question.questionPdfUrl = downloadUrl;
        question.questionPdfPath = pdfFile.path;
        question.questionPdfFileName = path.basename(storagePath);
        question.questionPdfSize = await pdfFile.length();
      } else {
        question.answerPdfUrl = downloadUrl;
        question.answerPdfPath = pdfFile.path;
        question.answerPdfFileName = path.basename(storagePath);
        question.answerPdfSize = await pdfFile.length();
      }

      print('PDF uploaded with correct MIME type: application/pdf');
    } catch (e) {
      debugPrint('Failed to upload PDF file: $e');
      throw e;
    }
  }

  Future<List<QuestionModel>> getAllQuestions() async {
    try {
      List<QuestionModel> allQuestions = [];

      final streamsSnapshot = await _firestore.collection('data').get();

      for (var streamDoc in streamsSnapshot.docs) {
        try {
          final questionsSnapshot =
              await streamDoc.reference.collection('questions').get();

          for (var questionDoc in questionsSnapshot.docs) {
            try {
              allQuestions.add(
                  QuestionModel.fromMap(questionDoc.data(), questionDoc.id));
            } catch (e) {
              debugPrint(
                  'Error parsing question document ${questionDoc.id}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error getting questions for stream ${streamDoc.id}: $e');
        }
      }

      allQuestions.sort((a, b) =>
          b.uploadedAt?.compareTo(a.uploadedAt ?? DateTime.now()) ?? 0);

      return allQuestions;
    } catch (e) {
      debugPrint('Failed to get questions: $e');
      throw Exception('Failed to get questions: $e');
    }
  }

  Future<List<QuestionModel>> getQuestionsByStream(String stream) async {
    try {
      final questionsSnapshot = await _firestore
          .collection('data')
          .doc(stream)
          .collection('questions')
          .get();

      return questionsSnapshot.docs
          .map((doc) => QuestionModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get questions for stream $stream: $e');
      throw Exception('Failed to get questions for stream $stream: $e');
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      // Find the question document across all streams
      final streamsSnapshot = await _firestore.collection('data').get();

      for (var streamDoc in streamsSnapshot.docs) {
        final questionDoc = await streamDoc.reference
            .collection('questions')
            .doc(questionId)
            .get();

        if (questionDoc.exists) {
          final questionData = questionDoc.data()!;

          // Delete original files from storage
          if (questionData['questionFileUrl'] != null) {
            try {
              final questionFileRef =
                  _storage.refFromURL(questionData['questionFileUrl']);
              await questionFileRef.delete();
            } catch (e) {
              debugPrint('Error deleting original question file: $e');
            }
          }

          if (questionData['answerFileUrl'] != null) {
            try {
              final answerFileRef =
                  _storage.refFromURL(questionData['answerFileUrl']);
              await answerFileRef.delete();
            } catch (e) {
              debugPrint('Error deleting original answer file: $e');
            }
          }

          // Delete PDF files from storage
          if (questionData['questionPdfUrl'] != null) {
            try {
              final questionPdfRef =
                  _storage.refFromURL(questionData['questionPdfUrl']);
              await questionPdfRef.delete();
            } catch (e) {
              debugPrint('Error deleting question PDF file: $e');
            }
          }

          if (questionData['answerPdfUrl'] != null) {
            try {
              final answerPdfRef =
                  _storage.refFromURL(questionData['answerPdfUrl']);
              await answerPdfRef.delete();
            } catch (e) {
              debugPrint('Error deleting answer PDF file: $e');
            }
          }

          // Delete document from Firestore
          await questionDoc.reference.delete();
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to delete question: $e');
      throw Exception('Failed to delete question: $e');
    }
  }

  // Get questions by multiple filters
  Future<List<QuestionModel>> getQuestionsByFilters({
    String? stream,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
  }) async {
    try {
      List<QuestionModel> filteredQuestions = [];

      if (stream != null) {
        final questionsSnapshot = await _firestore
            .collection('data')
            .doc(stream)
            .collection('questions')
            .get();

        for (var questionDoc in questionsSnapshot.docs) {
          final question =
              QuestionModel.fromMap(questionDoc.data(), questionDoc.id);

          if (_matchesFilters(
              question, level, topic, subtopic, language, chapter, type)) {
            filteredQuestions.add(question);
          }
        }
      } else {
        final allQuestions = await getAllQuestions();

        for (var question in allQuestions) {
          if (_matchesFilters(
              question, level, topic, subtopic, language, chapter, type)) {
            filteredQuestions.add(question);
          }
        }
      }

      return filteredQuestions;
    } catch (e) {
      debugPrint('Failed to get questions by filters: $e');
      throw Exception('Failed to get questions by filters: $e');
    }
  }

  // Helper method to check if a question matches the filters
  bool _matchesFilters(
    QuestionModel question,
    String? level,
    String? topic,
    String? subtopic,
    String? language,
    String? chapter,
    String? type,
  ) {
    if (level != null && question.level != level) return false;
    if (topic != null && question.topic != topic) return false;
    if (subtopic != null && question.subtopic != subtopic) return false;
    if (language != null && question.language != language) return false;
    if (chapter != null && question.chapter != chapter) return false;
    if (type != null && question.type != type) return false;
    return true;
  }

  // Get questions count
  Future<int> getQuestionsCount() async {
    try {
      int totalCount = 0;
      final streamsSnapshot = await _firestore.collection('data').get();

      for (var streamDoc in streamsSnapshot.docs) {
        final questionsSnapshot =
            await streamDoc.reference.collection('questions').get();
        totalCount += questionsSnapshot.docs.length;
      }

      return totalCount;
    } catch (e) {
      debugPrint('Failed to get questions count: $e');
      return 0;
    }
  }

  // Get questions count by stream
  Future<int> getQuestionsCountByStream(String stream) async {
    try {
      final questionsSnapshot = await _firestore
          .collection('data')
          .doc(stream)
          .collection('questions')
          .get();

      return questionsSnapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get questions count for stream $stream: $e');
      return 0;
    }
  }

  // Stream questions for real-time updates
  Stream<List<QuestionModel>> streamQuestionsByStream(String stream) {
    return _firestore
        .collection('data')
        .doc(stream)
        .collection('questions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuestionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Update question metadata
  Future<void> updateQuestion(QuestionModel question) async {
    try {
      await _firestore
          .collection('data')
          .doc(question.stream)
          .collection('questions')
          .doc(question.questionId)
          .update(question.toMap());
    } catch (e) {
      debugPrint('Failed to update question: $e');
      throw Exception('Failed to update question: $e');
    }
  }

  // Get question by ID
  Future<QuestionModel?> getQuestionById(String questionId) async {
    try {
      final streamsSnapshot = await _firestore.collection('data').get();

      for (var streamDoc in streamsSnapshot.docs) {
        final questionDoc = await streamDoc.reference
            .collection('questions')
            .doc(questionId)
            .get();

        if (questionDoc.exists) {
          return QuestionModel.fromMap(questionDoc.data()!, questionDoc.id);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Failed to get question by ID: $e');
      return null;
    }
  }

  // Check if question exists
  Future<bool> questionExists(String questionId) async {
    try {
      final question = await getQuestionById(questionId);
      return question != null;
    } catch (e) {
      debugPrint('Error checking question existence: $e');
      return false;
    }
  }

  // Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final stats = <String, dynamic>{
        'totalQuestions': 0,
        'questionsWithPdf': 0,
        'originalFilesSize': 0,
        'pdfFilesSize': 0,
        'totalSize': 0,
      };

      final allQuestions = await getAllQuestions();
      stats['totalQuestions'] = allQuestions.length;

      int questionsWithPdf = 0;
      int originalSize = 0;
      int pdfSize = 0;

      for (final question in allQuestions) {
        // Count original file sizes
        originalSize +=
            (question.questionFileSize ?? 0) + (question.answerFileSize ?? 0);

        // Count PDF file sizes
        if (question.questionPdfSize != null &&
            question.answerPdfSize != null) {
          questionsWithPdf++;
          pdfSize += question.questionPdfSize! + question.answerPdfSize!;
        }
      }

      stats['questionsWithPdf'] = questionsWithPdf;
      stats['originalFilesSize'] = originalSize;
      stats['pdfFilesSize'] = pdfSize;
      stats['totalSize'] = originalSize + pdfSize;

      return stats;
    } catch (e) {
      debugPrint('Failed to get storage stats: $e');
      return {
        'totalQuestions': 0,
        'questionsWithPdf': 0,
        'originalFilesSize': 0,
        'pdfFilesSize': 0,
        'totalSize': 0,
      };
    }
  }
}
