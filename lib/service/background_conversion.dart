import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:question_bank/service/doc_converter.dart';

class BackgroundConversionService {
  static final BackgroundConversionService _instance =
      BackgroundConversionService._internal();
  factory BackgroundConversionService() => _instance;
  BackgroundConversionService._internal();

  // Queue for pending conversions
  final Queue<ConversionTask> _conversionQueue = Queue<ConversionTask>();

  // Cache for completed conversions
  final Map<String, String?> _conversionCache = {};

  // Currently converting files
  final Set<String> _currentlyConverting = {};

  // Completion listeners
  final Map<String, List<void Function(String?)>> _completionListeners = {};

  // Progress listeners
  final Map<String, List<void Function(ConversionProgress)>>
      _progressListeners = {};

  // Background processing
  bool _isProcessing = false;
  Timer? _processingTimer;

  /// Start background conversion for a list of question models
  void startBatchConversion(List<dynamic> questionModels, int currentIndex) {
    debugPrint(
        'Starting batch conversion for ${questionModels.length} questions, current index: $currentIndex');

    // Clear existing queue and add new tasks with priorities
    _conversionQueue.clear();

    // Add current question and answer with highest priority
    if (currentIndex < questionModels.length) {
      final currentModel = questionModels[currentIndex];
      _addConversionTask(currentModel.questionFile.path,
          ConversionPriority.immediate, 'question');
      _addConversionTask(
          currentModel.answerFile.path, ConversionPriority.immediate, 'answer');
    }

    // Add next few questions with high priority
    for (int i = currentIndex + 1;
        i < questionModels.length && i < currentIndex + 3;
        i++) {
      final model = questionModels[i];
      _addConversionTask(
          model.questionFile.path, ConversionPriority.high, 'question');
      _addConversionTask(
          model.answerFile.path, ConversionPriority.high, 'answer');
    }

    // Add remaining questions with normal priority
    for (int i = currentIndex + 3; i < questionModels.length; i++) {
      final model = questionModels[i];
      _addConversionTask(
          model.questionFile.path, ConversionPriority.normal, 'question');
      _addConversionTask(
          model.answerFile.path, ConversionPriority.normal, 'answer');
    }

    // Add previous questions with low priority
    for (int i = 0; i < currentIndex; i++) {
      final model = questionModels[i];
      _addConversionTask(
          model.questionFile.path, ConversionPriority.low, 'question');
      _addConversionTask(
          model.answerFile.path, ConversionPriority.low, 'answer');
    }

    _startProcessing();
  }

  /// Update priorities when user changes current question
  void updateCurrentQuestion(List<dynamic> questionModels, int newIndex) {
    debugPrint('Updating current question to index: $newIndex');

    if (newIndex >= questionModels.length) return;

    final currentModel = questionModels[newIndex];

    // Promote current question and answer to immediate priority
    _promoteToImmediatePriority(currentModel.questionFile.path);
    _promoteToImmediatePriority(currentModel.answerFile.path);

    // Promote next few questions to high priority
    for (int i = newIndex + 1;
        i < questionModels.length && i < newIndex + 3;
        i++) {
      final model = questionModels[i];
      _promoteToHighPriority(model.questionFile.path);
      _promoteToHighPriority(model.answerFile.path);
    }
  }

  /// Add conversion task to queue
  void _addConversionTask(
      String filePath, ConversionPriority priority, String type) {
    // Skip if already cached or currently converting
    if (_conversionCache.containsKey(filePath) ||
        _currentlyConverting.contains(filePath)) {
      return;
    }

    // Check if task already exists in queue
    final existingTaskIndex = _conversionQueue
        .toList()
        .indexWhere((task) => task.filePath == filePath);
    if (existingTaskIndex != -1) {
      // Update priority if new priority is higher
      final existingTask = _conversionQueue.elementAt(existingTaskIndex);
      if (priority.index > existingTask.priority.index) {
        _conversionQueue.remove(existingTask);
        _conversionQueue.add(ConversionTask(filePath, priority, type));
        _sortQueue();
      }
      return;
    }

    _conversionQueue.add(ConversionTask(filePath, priority, type));
    _sortQueue();
  }

  /// Promote file to immediate priority
  void _promoteToImmediatePriority(String filePath) {
    final task = _conversionQueue.firstWhere(
      (task) => task.filePath == filePath,
      orElse: () => ConversionTask('', ConversionPriority.normal, ''),
    );

    if (task.filePath.isNotEmpty) {
      _conversionQueue.remove(task);
      _conversionQueue.addFirst(
          ConversionTask(filePath, ConversionPriority.immediate, task.type));
    }
  }

  /// Promote file to high priority
  void _promoteToHighPriority(String filePath) {
    final taskIndex = _conversionQueue
        .toList()
        .indexWhere((task) => task.filePath == filePath);
    if (taskIndex != -1) {
      final task = _conversionQueue.elementAt(taskIndex);
      if (task.priority.index < ConversionPriority.high.index) {
        _conversionQueue.remove(task);
        _conversionQueue
            .add(ConversionTask(filePath, ConversionPriority.high, task.type));
        _sortQueue();
      }
    }
  }

  /// Sort queue by priority
  void _sortQueue() {
    final list = _conversionQueue.toList();
    list.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    _conversionQueue.clear();
    _conversionQueue.addAll(list);
  }

  /// Start background processing
  void _startProcessing() {
    if (_isProcessing) return;

    _isProcessing = true;
    _processNextTask();
  }

  /// Process next task in queue
  Future<void> _processNextTask() async {
    if (_conversionQueue.isEmpty) {
      _isProcessing = false;
      return;
    }

    final task = _conversionQueue.removeFirst();

    // Skip if already cached or currently converting
    if (_conversionCache.containsKey(task.filePath) ||
        _currentlyConverting.contains(task.filePath)) {
      _scheduleNextTask();
      return;
    }

    _currentlyConverting.add(task.filePath);

    // Notify progress listeners
    _notifyProgress(task.filePath, ConversionProgress.started);

    debugPrint(
        'Converting ${task.type}: ${task.filePath} (Priority: ${task.priority.name})');

    try {
      final result = await DocumentConverterService.convertToPdf(task.filePath);
      _conversionCache[task.filePath] = result;

      // Notify completion listeners
      _notifyCompletion(task.filePath, result);
      _notifyProgress(
          task.filePath,
          result != null
              ? ConversionProgress.completed
              : ConversionProgress.failed);

      debugPrint(
          'Conversion completed for ${task.filePath}: ${result != null ? 'Success' : 'Failed'}');
    } catch (e) {
      debugPrint('Conversion failed for ${task.filePath}: $e');
      _conversionCache[task.filePath] = null;
      _notifyCompletion(task.filePath, null);
      _notifyProgress(task.filePath, ConversionProgress.failed);
    } finally {
      _currentlyConverting.remove(task.filePath);
    }

    _scheduleNextTask();
  }

  /// Schedule next task processing
  void _scheduleNextTask() {
    // Add small delay to prevent overwhelming the system
    _processingTimer?.cancel();
    _processingTimer =
        Timer(const Duration(milliseconds: 500), _processNextTask);
  }

  /// Get cached conversion result
  String? getCachedConversion(String filePath) {
    return _conversionCache[filePath];
  }

  /// Check if file is currently being converted
  bool isConverting(String filePath) {
    return _currentlyConverting.contains(filePath);
  }

  /// Check if file is in queue
  bool isInQueue(String filePath) {
    return _conversionQueue.any((task) => task.filePath == filePath);
  }

  /// Add completion listener
  void addCompletionListener(String filePath, void Function(String?) callback) {
    _completionListeners.putIfAbsent(filePath, () => []).add(callback);
  }

  /// Remove completion listener
  void removeCompletionListener(
      String filePath, void Function(String?) callback) {
    _completionListeners[filePath]?.remove(callback);
    if (_completionListeners[filePath]?.isEmpty == true) {
      _completionListeners.remove(filePath);
    }
  }

  /// Add progress listener
  void addProgressListener(
      String filePath, void Function(ConversionProgress) callback) {
    _progressListeners.putIfAbsent(filePath, () => []).add(callback);
  }

  /// Remove progress listener
  void removeProgressListener(
      String filePath, void Function(ConversionProgress) callback) {
    _progressListeners[filePath]?.remove(callback);
    if (_progressListeners[filePath]?.isEmpty == true) {
      _progressListeners.remove(filePath);
    }
  }

  /// Notify completion listeners
  void _notifyCompletion(String filePath, String? result) {
    final listeners = _completionListeners[filePath];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(result);
        } catch (e) {
          debugPrint('Error in completion listener: $e');
        }
      }
    }
  }

  /// Notify progress listeners
  void _notifyProgress(String filePath, ConversionProgress progress) {
    final listeners = _progressListeners[filePath];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(progress);
        } catch (e) {
          debugPrint('Error in progress listener: $e');
        }
      }
    }
  }

  /// Clear all caches and stop processing
  void clear() {
    _processingTimer?.cancel();
    _conversionQueue.clear();
    _currentlyConverting.clear();
    _completionListeners.clear();
    _progressListeners.clear();
    _isProcessing = false;

    debugPrint('Background conversion service cleared');
  }

  /// Clean up old cache entries
  void cleanupCache() {
    // Remove cached entries that are no longer needed
    // Keep only recent entries to prevent memory bloat
    if (_conversionCache.length > 50) {
      final entries = _conversionCache.entries.toList();
      // Remove oldest entries (this is a simple approach; could be improved with timestamps)
      for (int i = 0; i < 20; i++) {
        _conversionCache.remove(entries[i].key);
      }
    }
  }

  /// Get conversion statistics
  ConversionStats getStats() {
    return ConversionStats(
      cachedCount: _conversionCache.length,
      queuedCount: _conversionQueue.length,
      convertingCount: _currentlyConverting.length,
      successfulConversions:
          _conversionCache.values.where((v) => v != null).length,
      failedConversions: _conversionCache.values.where((v) => v == null).length,
    );
  }
}

/// Conversion task model
class ConversionTask {
  final String filePath;
  final ConversionPriority priority;
  final String type; // 'question' or 'answer'

  ConversionTask(this.filePath, this.priority, this.type);
}

/// Conversion priority levels
enum ConversionPriority {
  low(0),
  normal(1),
  high(2),
  immediate(3);

  const ConversionPriority(this.value);
  final int value;
}

/// Conversion progress states
enum ConversionProgress {
  queued,
  started,
  completed,
  failed,
}

/// Conversion statistics
class ConversionStats {
  final int cachedCount;
  final int queuedCount;
  final int convertingCount;
  final int successfulConversions;
  final int failedConversions;

  ConversionStats({
    required this.cachedCount,
    required this.queuedCount,
    required this.convertingCount,
    required this.successfulConversions,
    required this.failedConversions,
  });

  @override
  String toString() {
    return 'Cached: $cachedCount, Queued: $queuedCount, Converting: $convertingCount, Success: $successfulConversions, Failed: $failedConversions';
  }
}
