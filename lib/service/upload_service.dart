// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:question_bank/question_model.dart';
// import 'package:question_bank/service/local_db.dart';
// import 'package:question_bank/service/firebase_service.dart';
// import 'package:question_bank/service/doc_converter.dart';

// class EnhancedUploadProcessor {
//   final LocalDatabaseService _localDb = LocalDatabaseService();
//   final FirebaseService _firebaseService = FirebaseService();

//   /// Process upload queue with PDF generation and caching
//   Future<UploadResult> processUploadQueue({
//     required Function(String status) onStatusUpdate,
//     required Function(double progress) onProgressUpdate,
//     required Function(UploadItemResult result) onItemComplete,
//   }) async {
//     try {
//       final queueItems = await _localDb.getUploadQueue();
//       if (queueItems.isEmpty) {
//         return UploadResult(
//           totalItems: 0,
//           successfulUploads: 0,
//           failedUploads: 0,
//           errors: [],
//         );
//       }

//       onStatusUpdate('Starting upload process...');
//       onProgressUpdate(0.0);

//       int successfulUploads = 0;
//       int failedUploads = 0;
//       List<String> errors = [];

//       for (int i = 0; i < queueItems.length; i++) {
//         final queueItem = queueItems[i];

//         try {
//           onStatusUpdate(
//               'Processing ${i + 1}/${queueItems.length}: Preparing files...');

//           // Get the question pair
//           final questionPairs = await _localDb.getQuestionPairsWithQueue();
//           final questionPairWithQueue = questionPairs.firstWhere(
//             (pair) => pair.questionPair.id == queueItem.questionPairId,
//           );

//           final questionPair = questionPairWithQueue.questionPair;

//           // Process this item
//           final itemResult = await _processUploadItem(
//             queueItem: queueItem,
//             questionPair: questionPair,
//             currentIndex: i,
//             totalItems: queueItems.length,
//             onStatusUpdate: onStatusUpdate,
//           );

//           if (itemResult.success) {
//             successfulUploads++;

//             // Increment upload count and remove from queue
//             await _localDb.incrementUploadCount(questionPair.id!);
//             await _localDb.removeFromUploadQueue(queueItem.id!);
//           } else {
//             failedUploads++;
//             errors.add('${questionPair.baseName}: ${itemResult.error}');
//           }

//           // Notify about item completion
//           onItemComplete(itemResult);

//           // Update overall progress
//           onProgressUpdate((i + 1) / queueItems.length);
//         } catch (e) {
//           failedUploads++;
//           errors.add('Item ${queueItem.questionPairId}: $e');

//           onItemComplete(UploadItemResult(
//             questionPairId: queueItem.questionPairId,
//             baseName: 'Unknown',
//             success: false,
//             error: e.toString(),
//           ));
//         }
//       }

//       onStatusUpdate('Upload process completed!');
//       onProgressUpdate(1.0);

//       return UploadResult(
//         totalItems: queueItems.length,
//         successfulUploads: successfulUploads,
//         failedUploads: failedUploads,
//         errors: errors,
//       );
//     } catch (e) {
//       debugPrint('Error in upload process: $e');
//       return UploadResult(
//         totalItems: 0,
//         successfulUploads: 0,
//         failedUploads: 0,
//         errors: ['Upload process failed: $e'],
//       );
//     }
//   }

//   /// Process a single upload item with PDF generation
//   Future<UploadItemResult> _processUploadItem({
//     required UploadQueueItem queueItem,
//     required LocalQuestionPair questionPair,
//     required int currentIndex,
//     required int totalItems,
//     required Function(String status) onStatusUpdate,
//   }) async {
//     try {
//       final baseName = questionPair.baseName;
//       onStatusUpdate(
//           '${currentIndex + 1}/$totalItems: Converting $baseName to PDF...');

//       // Generate or get cached PDFs
//       String? questionPdfPath;
//       String? answerPdfPath;

//       // Check for cached PDFs first
//       questionPdfPath =
//           await _localDb.getCachedPdfPath(questionPair.questionFilePath);
//       if (questionPdfPath == null) {
//         onStatusUpdate(
//             '${currentIndex + 1}/$totalItems: Converting question file for $baseName...');
//         questionPdfPath = await DocumentConverterService.convertToPdf(
//             questionPair.questionFilePath);
//         if (questionPdfPath != null) {
//           await _localDb.cachePdfConversion(
//               questionPair.questionFilePath, questionPdfPath);
//         }
//       } else {
//         debugPrint('Using cached question PDF: $questionPdfPath');
//       }

//       answerPdfPath =
//           await _localDb.getCachedPdfPath(questionPair.answerFilePath);
//       if (answerPdfPath == null) {
//         onStatusUpdate(
//             '${currentIndex + 1}/$totalItems: Converting answer file for $baseName...');
//         answerPdfPath = await DocumentConverterService.convertToPdf(
//             questionPair.answerFilePath);
//         if (answerPdfPath != null) {
//           await _localDb.cachePdfConversion(
//               questionPair.answerFilePath, answerPdfPath);
//         }
//       } else {
//         debugPrint('Using cached answer PDF: $answerPdfPath');
//       }

//       // Update question pair with PDF paths if they were generated
//       if ((questionPdfPath != null && questionPair.questionPdfPath == null) ||
//           (answerPdfPath != null && questionPair.answerPdfPath == null)) {
//         await _localDb.updateQuestionPairPdfPaths(
//           questionPair.id!,
//           questionPdfPath,
//           answerPdfPath,
//         );
//       }

//       onStatusUpdate('${currentIndex + 1}/$totalItems: Uploading $baseName...');

//       // Create question model with all file paths
//       final question = QuestionModel(
//         stream: queueItem.stream,
//         level: queueItem.level,
//         topic: queueItem.topic,
//         subtopic: queueItem.subtopic,
//         language: queueItem.language,
//         chapter: queueItem.chapter,
//         type: queueItem.type,
//         questionFilePath: questionPair.questionFilePath,
//         answerFilePath: questionPair.answerFilePath,
//         questionPdfPath: questionPdfPath,
//         answerPdfPath: answerPdfPath,
//       );

//       // Upload with progress tracking
//       await _firebaseService.uploadQuestionWithProgress(
//         question,
//         (progress) {
//           // This progress is for individual file upload
//           onStatusUpdate(
//               '${currentIndex + 1}/$totalItems: Uploading $baseName (${(progress * 100).toInt()}%)...');
//         },
//       );

//       return UploadItemResult(
//         questionPairId: questionPair.id!,
//         baseName: baseName,
//         success: true,
//         hasPdfs: questionPdfPath != null && answerPdfPath != null,
//         questionPdfGenerated: questionPdfPath != null,
//         answerPdfGenerated: answerPdfPath != null,
//       );
//     } catch (e) {
//       debugPrint('Error processing upload item: $e');
//       return UploadItemResult(
//         questionPairId: questionPair.id!,
//         baseName: questionPair.baseName,
//         success: false,
//         error: e.toString(),
//       );
//     }
//   }

//   /// Get statistics about PDF conversion cache
//   Future<CacheStatistics> getCacheStatistics() async {
//     try {
//       final questionPairs = await _localDb.getAllQuestionPairs();

//       int totalPairs = questionPairs.length;
//       int withPdfs = 0;
//       int withQuestionPdf = 0;
//       int withAnswerPdf = 0;

//       for (final pair in questionPairs) {
//         if (pair.questionPdfPath != null) withQuestionPdf++;
//         if (pair.answerPdfPath != null) withAnswerPdf++;
//         if (pair.questionPdfPath != null && pair.answerPdfPath != null)
//           withPdfs++;
//       }

//       return CacheStatistics(
//         totalQuestionPairs: totalPairs,
//         pairsWithBothPdfs: withPdfs,
//         pairsWithQuestionPdf: withQuestionPdf,
//         pairsWithAnswerPdf: withAnswerPdf,
//         conversionCacheHitRate: totalPairs > 0 ? (withPdfs / totalPairs) : 0.0,
//       );
//     } catch (e) {
//       debugPrint('Error getting cache statistics: $e');
//       return CacheStatistics(
//         totalQuestionPairs: 0,
//         pairsWithBothPdfs: 0,
//         pairsWithQuestionPdf: 0,
//         pairsWithAnswerPdf: 0,
//         conversionCacheHitRate: 0.0,
//       );
//     }
//   }

//   /// Pre-convert PDFs for all question pairs to improve upload speed
//   Future<void> preConvertAllPdfs({
//     required Function(String status) onStatusUpdate,
//     required Function(double progress) onProgressUpdate,
//   }) async {
//     try {
//       final questionPairs = await _localDb.getAllQuestionPairs();

//       if (questionPairs.isEmpty) {
//         onStatusUpdate('No question pairs found');
//         return;
//       }

//       onStatusUpdate(
//           'Starting PDF pre-conversion for ${questionPairs.length} question pairs...');

//       int processed = 0;
//       int converted = 0;
//       int cached = 0;

//       for (final pair in questionPairs) {
//         try {
//           onStatusUpdate(
//               'Converting ${pair.baseName} (${processed + 1}/${questionPairs.length})...');

//           // Process question file
//           String? questionPdfPath =
//               await _localDb.getCachedPdfPath(pair.questionFilePath);
//           if (questionPdfPath == null) {
//             questionPdfPath = await DocumentConverterService.convertToPdf(
//                 pair.questionFilePath);
//             if (questionPdfPath != null) {
//               await _localDb.cachePdfConversion(
//                   pair.questionFilePath, questionPdfPath);
//               converted++;
//             }
//           } else {
//             cached++;
//           }

//           // Process answer file
//           String? answerPdfPath =
//               await _localDb.getCachedPdfPath(pair.answerFilePath);
//           if (answerPdfPath == null) {
//             answerPdfPath = await DocumentConverterService.convertToPdf(
//                 pair.answerFilePath);
//             if (answerPdfPath != null) {
//               await _localDb.cachePdfConversion(
//                   pair.answerFilePath, answerPdfPath);
//               converted++;
//             }
//           } else {
//             cached++;
//           }

//           // Update question pair with PDF paths
//           if (questionPdfPath != null || answerPdfPath != null) {
//             await _localDb.updateQuestionPairPdfPaths(
//               pair.id!,
//               questionPdfPath,
//               answerPdfPath,
//             );
//           }

//           processed++;
//           onProgressUpdate(processed / questionPairs.length);
//         } catch (e) {
//           debugPrint('Error converting PDFs for ${pair.baseName}: $e');
//           processed++;
//           continue;
//         }
//       }

//       onStatusUpdate(
//           'Pre-conversion completed: $converted new PDFs, $cached from cache');
//     } catch (e) {
//       debugPrint('Error in PDF pre-conversion: $e');
//       onStatusUpdate('Pre-conversion failed: $e');
//     }
//   }
// }

// /// Result of the entire upload process
// class UploadResult {
//   final int totalItems;
//   final int successfulUploads;
//   final int failedUploads;
//   final List<String> errors;

//   UploadResult({
//     required this.totalItems,
//     required this.successfulUploads,
//     required this.failedUploads,
//     required this.errors,
//   });

//   bool get hasErrors => errors.isNotEmpty;
//   double get successRate =>
//       totalItems > 0 ? successfulUploads / totalItems : 0.0;
// }

// /// Result of uploading a single item
// class UploadItemResult {
//   final int questionPairId;
//   final String baseName;
//   final bool success;
//   final String? error;
//   final bool hasPdfs;
//   final bool questionPdfGenerated;
//   final bool answerPdfGenerated;

//   UploadItemResult({
//     required this.questionPairId,
//     required this.baseName,
//     required this.success,
//     this.error,
//     this.hasPdfs = false,
//     this.questionPdfGenerated = false,
//     this.answerPdfGenerated = false,
//   });
// }

// /// Statistics about PDF conversion cache
// class CacheStatistics {
//   final int totalQuestionPairs;
//   final int pairsWithBothPdfs;
//   final int pairsWithQuestionPdf;
//   final int pairsWithAnswerPdf;
//   final double conversionCacheHitRate;

//   CacheStatistics({
//     required this.totalQuestionPairs,
//     required this.pairsWithBothPdfs,
//     required this.pairsWithQuestionPdf,
//     required this.pairsWithAnswerPdf,
//     required this.conversionCacheHitRate,
//   });

//   String get cacheHitRatePercentage =>
//       '${(conversionCacheHitRate * 100).toStringAsFixed(1)}%';
// }
