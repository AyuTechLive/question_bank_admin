import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:question_bank/question_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadQuestion(QuestionModel question) async {
    try {
      // Generate unique question ID
      final docRef = _firestore
          .collection('data')
          .doc(question.stream)
          .collection('questions')
          .doc();
      question.questionId = docRef.id;

      // Upload question file with proper threading
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/${question.stream}/$questionFileName');

      // Use await instead of then() to avoid threading issues
      final questionUploadTask =
          questionRef.putFile(File(question.questionFilePath!));
      final questionTaskSnapshot = await questionUploadTask;
      question.questionFileUrl =
          await questionTaskSnapshot.ref.getDownloadURL();

      // Upload answer file with proper threading
      String answerFileName =
          '${question.questionId}_answer${path.extension(question.answerFilePath!)}';
      final answerRef =
          _storage.ref().child('answers/${question.stream}/$answerFileName');

      // Use await instead of then() to avoid threading issues
      final answerUploadTask =
          answerRef.putFile(File(question.answerFilePath!));
      final answerTaskSnapshot = await answerUploadTask;
      question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();

      // Save to Firestore
      await docRef.set(question.toMap());
    } catch (e) {
      debugPrint('Failed to upload question: $e');
      throw Exception('Failed to upload question: $e');
    }
  }

  // Upload with progress callback (thread-safe version)
  Future<void> uploadQuestionWithProgress(
    QuestionModel question,
    Function(double)? onProgress,
  ) async {
    try {
      // Generate unique question ID
      final docRef = _firestore
          .collection('data')
          .doc(question.stream)
          .collection('questions')
          .doc();
      question.questionId = docRef.id;

      double totalProgress = 0.0;

      // Upload question file
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/${question.stream}/$questionFileName');

      final questionUploadTask =
          questionRef.putFile(File(question.questionFilePath!));

      // Listen to progress with proper thread handling
      questionUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          totalProgress = progress * 0.5; // Question file is 50% of total

          // Ensure callback runs on main thread
          if (onProgress != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onProgress(totalProgress);
            });
          }
        },
        onError: (error) {
          debugPrint('Question upload progress error: $error');
        },
      );

      final questionTaskSnapshot = await questionUploadTask;
      question.questionFileUrl =
          await questionTaskSnapshot.ref.getDownloadURL();

      // Upload answer file
      String answerFileName =
          '${question.questionId}_answer${path.extension(question.answerFilePath!)}';
      final answerRef =
          _storage.ref().child('answers/${question.stream}/$answerFileName');

      final answerUploadTask =
          answerRef.putFile(File(question.answerFilePath!));

      // Listen to progress with proper thread handling
      answerUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          totalProgress =
              0.5 + (progress * 0.5); // Answer file is remaining 50%

          // Ensure callback runs on main thread
          if (onProgress != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onProgress(totalProgress);
            });
          }
        },
        onError: (error) {
          debugPrint('Answer upload progress error: $error');
        },
      );

      final answerTaskSnapshot = await answerUploadTask;
      question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();

      // Save to Firestore
      await docRef.set(question.toMap());

      // Final progress callback
      if (onProgress != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onProgress(1.0);
        });
      }
    } catch (e) {
      debugPrint('Failed to upload question with progress: $e');
      throw Exception('Failed to upload question: $e');
    }
  }

// Add this method to your existing firebase_service.dart file

  /// Check if a question with the same metadata already exists
  Future<bool> questionExistsWithMetadata({
    required String stream,
    required String level,
    required String topic,
    required String subtopic,
    required String language,
    required String chapter,
    required String type,
  }) async {
    try {
      final questionsSnapshot = await _firestore
          .collection('data')
          .doc(stream)
          .collection('questions')
          .where('level', isEqualTo: level)
          .where('topic', isEqualTo: topic)
          .where('subtopic', isEqualTo: subtopic)
          .where('language', isEqualTo: language)
          .where('chapter', isEqualTo: chapter)
          .where('type', isEqualTo: type)
          .limit(1)
          .get();

      return questionsSnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking question existence: $e');
      // If there's an error checking, allow upload to proceed
      return false;
    }
  }

  Future<List<QuestionModel>> getAllQuestions() async {
    try {
      List<QuestionModel> allQuestions = [];

      // Get all streams
      final streamsSnapshot = await _firestore.collection('data').get();

      for (var streamDoc in streamsSnapshot.docs) {
        try {
          // Get questions for each stream
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

      // Sort by upload date
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

          // Delete files from storage with proper error handling
          if (questionData['questionFileUrl'] != null) {
            try {
              final questionFileRef =
                  _storage.refFromURL(questionData['questionFileUrl']);
              await questionFileRef.delete();
            } catch (e) {
              debugPrint('Error deleting question file: $e');
              // Continue with deletion even if file deletion fails
            }
          }

          if (questionData['answerFileUrl'] != null) {
            try {
              final answerFileRef =
                  _storage.refFromURL(questionData['answerFileUrl']);
              await answerFileRef.delete();
            } catch (e) {
              debugPrint('Error deleting answer file: $e');
              // Continue with deletion even if file deletion fails
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
        // If stream is specified, search only in that stream
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
        // If no stream specified, search all streams
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
}
