import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:question_bank/question_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadQuestion(QuestionModel question) async {
    try {
      print('Starting upload for question...');

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

      // Upload question file
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/${question.stream}/$questionFileName');

      print('Uploading question file: $questionFileName');

      try {
        final questionUploadTask = questionRef.putFile(questionFile);
        final questionTaskSnapshot = await questionUploadTask;
        question.questionFileUrl =
            await questionTaskSnapshot.ref.getDownloadURL();
        print(
            'Question file uploaded successfully: ${question.questionFileUrl}');
      } catch (e) {
        print('Error uploading question file: $e');
        throw Exception('Failed to upload question file: $e');
      }

      // Upload answer file
      String answerFileName =
          '${question.questionId}_answer${path.extension(question.answerFilePath!)}';
      final answerRef =
          _storage.ref().child('answers/${question.stream}/$answerFileName');

      print('Uploading answer file: $answerFileName');

      try {
        final answerUploadTask = answerRef.putFile(answerFile);
        final answerTaskSnapshot = await answerUploadTask;
        question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();
        print('Answer file uploaded successfully: ${question.answerFileUrl}');
      } catch (e) {
        print('Error uploading answer file: $e');
        throw Exception('Failed to upload answer file: $e');
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
        } catch (cleanupError) {
          print('Error during cleanup: $cleanupError');
        }
        throw Exception('Failed to save to Firestore: $e');
      }

      print('Question upload completed successfully');
    } catch (e) {
      print('Failed to upload question: $e');
      debugPrint('Failed to upload question: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  // Upload with progress callback (thread-safe version)
  Future<void> uploadQuestionWithProgress(
    QuestionModel question,
    Function(double)? onProgress,
  ) async {
    try {
      print('Starting upload with progress tracking...');

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

      // Upload question file
      String questionFileName =
          '${question.questionId}_question${path.extension(question.questionFilePath!)}';
      final questionRef = _storage
          .ref()
          .child('questions/${question.stream}/$questionFileName');

      final questionUploadTask = questionRef.putFile(questionFile);

      // Listen to progress with proper thread handling
      questionUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            totalProgress = progress * 0.5; // Question file is 50% of total

            // Ensure callback runs on main thread
            if (onProgress != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onProgress(totalProgress);
              });
            }
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

      final answerUploadTask = answerRef.putFile(answerFile);

      // Listen to progress with proper thread handling
      answerUploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            totalProgress =
                0.5 + (progress * 0.5); // Answer file is remaining 50%

            // Ensure callback runs on main thread
            if (onProgress != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onProgress(totalProgress);
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Answer upload progress error: $error');
        },
      );

      final answerTaskSnapshot = await answerUploadTask;
      question.answerFileUrl = await answerTaskSnapshot.ref.getDownloadURL();

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

      print('Question upload with progress completed successfully');
    } catch (e) {
      debugPrint('Failed to upload question with progress: $e');
      rethrow;
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
