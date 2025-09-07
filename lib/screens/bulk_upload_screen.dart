import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:question_bank/service/local_db.dart';
import 'package:question_bank/service/metadata_service.dart';
import 'package:question_bank/service/firebase_service.dart';
import 'package:question_bank/question_model.dart';
import 'package:question_bank/widget/doc_viewer.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:async';
import 'package:flutter/foundation.dart';

class EnhancedBulkUploadScreen extends StatefulWidget {
  const EnhancedBulkUploadScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedBulkUploadScreen> createState() =>
      _EnhancedBulkUploadScreenState();
}

class _EnhancedBulkUploadScreenState extends State<EnhancedBulkUploadScreen>
    with WidgetsBindingObserver {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final MetadataService _metadataService = MetadataService();
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();

  List<QuestionPairWithQueue> questionPairs = [];
  List<QuestionPairWithQueue> filteredQuestionPairs = [];
  List<DatabaseInfo> databases = [];
  DatabaseInfo? selectedDatabase;
  QuestionPairWithQueue? selectedPair;
  bool isLoading = false;
  bool isUploading = false;
  bool _disposed = false;
  double uploadProgress = 0.0;
  String uploadStatus = '';
  int uploadQueueCount = 0;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Upload management
  StreamSubscription? _uploadSubscription;
  Completer<void>? _uploadCompleter;
  int _currentUploadIndex = 0;
  int _totalUploadItems = 0;

  // Metadata form data
  String? selectedStream;
  String? selectedLevel;
  String? selectedTopic;
  String? selectedSubtopic;
  String? selectedLanguage;
  String? selectedChapter;
  String? selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMetadata();
    _loadDatabases();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cancelUpload();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelUpload();
    }
  }

  void _onSearchChanged() {
    if (_disposed) return;
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterQuestions();
    });
  }

  void _filterQuestions() {
    if (_disposed) return;
    if (searchQuery.isEmpty) {
      filteredQuestionPairs = List.from(questionPairs);
    } else {
      filteredQuestionPairs = questionPairs
          .where((pair) =>
              pair.questionPair.baseName.toLowerCase().contains(searchQuery))
          .toList();
    }
  }

  Future<void> _loadMetadata() async {
    if (_disposed) return;
    try {
      await _metadataService.loadAllMetadata();
      if (!_disposed) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error loading metadata: $e');
      }
    }
  }

  Future<void> _loadDatabases() async {
    if (_disposed) return;
    setState(() {
      isLoading = true;
    });

    try {
      final dbs = await _localDb.getAllDatabases();
      if (!_disposed) {
        setState(() {
          databases = dbs;
          if (databases.isNotEmpty && selectedDatabase == null) {
            selectedDatabase = databases.first;
            _selectDatabase(selectedDatabase!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading databases: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error loading databases: $e');
      }
    } finally {
      if (!_disposed) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDatabase(DatabaseInfo database) async {
    if (_disposed) return;
    setState(() {
      isLoading = true;
      selectedDatabase = database;
    });

    try {
      await _localDb.selectDatabase(database.databaseName);
      await _loadQuestionPairs();
      await _loadUploadQueueCount();
    } catch (e) {
      debugPrint('Error selecting database: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error selecting database: $e');
      }
    } finally {
      if (!_disposed) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadQuestionPairs() async {
    if (selectedDatabase == null || _disposed) return;

    setState(() {
      isLoading = true;
    });

    try {
      final pairs = await _localDb.getQuestionPairsWithQueue();

      if (!_disposed) {
        setState(() {
          questionPairs = pairs;
          _filterQuestions();
          if (questionPairs.isNotEmpty && selectedPair == null) {
            selectedPair = questionPairs.first;
            _loadMetadataFromQueue();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading question pairs: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error loading question pairs: $e');
      }
    } finally {
      if (!_disposed) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUploadQueueCount() async {
    if (_disposed) return;
    try {
      final count = await _localDb.getUploadQueueCount();
      if (!_disposed) {
        setState(() {
          uploadQueueCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading upload queue count: $e');
    }
  }

  void _loadMetadataFromQueue() {
    if (_disposed) return;
    if (selectedPair?.queueItem != null) {
      final queue = selectedPair!.queueItem!;
      setState(() {
        selectedStream = queue.stream;
        selectedLevel = queue.level;
        selectedTopic = queue.topic;
        selectedSubtopic = queue.subtopic;
        selectedLanguage = queue.language;
        selectedChapter = queue.chapter;
        selectedType = queue.type;
      });
    } else {
      _clearMetadata();
    }
  }

  void _clearMetadata() {
    if (_disposed) return;
    setState(() {
      selectedStream = null;
      selectedLevel = null;
      selectedTopic = null;
      selectedSubtopic = null;
      selectedLanguage = null;
      selectedChapter = null;
      selectedType = null;
    });
  }

  void _showErrorSnackBar(String message) {
    if (_disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (_disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showCreateDatabaseDialog() async {
    if (_disposed) return;

    String? questionsFolder = await FilePicker.platform.getDirectoryPath();
    if (questionsFolder == null || _disposed) return;

    String? answersFolder = await FilePicker.platform.getDirectoryPath();
    if (answersFolder == null || _disposed) return;

    String databaseName = '';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.create_new_folder, color: Colors.blue),
              SizedBox(width: 8),
              Text('Create New Question Database'),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Questions Folder:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  questionsFolder,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Text(
                  'Answers Folder:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  answersFolder,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Database Name',
                    hintText: 'Enter a name for this question database',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    databaseName = value.trim();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, databaseName),
              child: const Text('Create Database'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && !_disposed) {
      setState(() {
        isLoading = true;
      });

      try {
        await _localDb.createNewDatabase(
          displayName: result,
          questionsFolder: questionsFolder,
          answersFolder: answersFolder,
        );

        if (!_disposed) {
          await _loadDatabases();

          final newDb = databases.firstWhere(
            (db) => db.displayName == result,
          );
          await _selectDatabase(newDb);
          await _retrieveQuestions(questionsFolder, answersFolder);

          _showSuccessSnackBar('Database "$result" created successfully');
        }
      } catch (e) {
        debugPrint('Error creating database: $e');
        if (!_disposed) {
          _showErrorSnackBar('Error creating database: $e');
        }
      } finally {
        if (!_disposed) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _showDatabaseSelector() async {
    if (_disposed) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.data_object, color: Colors.blue),
              SizedBox(width: 8),
              Text('Select Question Database'),
            ],
          ),
          content: Container(
            width: 500,
            height: 400,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateDatabaseDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Database'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: databases.isEmpty
                      ? const Center(
                          child: Text(
                            'No databases found.\nCreate a new one to get started.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: databases.length,
                          itemBuilder: (context, index) {
                            final db = databases[index];
                            final isSelected = selectedDatabase?.databaseName ==
                                db.databaseName;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                color: isSelected ? Colors.blue.shade50 : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        isSelected ? Colors.blue : Colors.grey,
                                    child: Text(
                                      db.questionCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    db.displayName,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Questions: ${db.questionCount} • Queue: ${db.uploadQueueCount} • Uploads: ${db.totalUploads}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        'Last accessed: ${_formatDate(db.lastAccessed)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: Colors.blue),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title:
                                                  const Text('Delete Database'),
                                              content: Text(
                                                'Are you sure you want to delete "${db.displayName}"?\n\nThis action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await _localDb.deleteDatabase(
                                                db.databaseName);
                                            await _loadDatabases();
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _selectDatabase(db);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _retrieveQuestions(
      String questionsPath, String answersPath) async {
    if (_disposed) return;

    setState(() {
      isLoading = true;
    });

    try {
      final questionsDir = Directory(questionsPath);
      final answersDir = Directory(answersPath);

      if (!questionsDir.existsSync() || !answersDir.existsSync()) {
        throw Exception('One or both folders do not exist');
      }

      final questionFiles = questionsDir
          .listSync()
          .where((file) => file is File && _isValidDocumentFile(file.path))
          .cast<File>()
          .toList();

      final answerFiles = answersDir
          .listSync()
          .where((file) => file is File && _isValidDocumentFile(file.path))
          .cast<File>()
          .toList();

      final Map<String, File> answerFileMap = {};
      for (final answerFile in answerFiles) {
        final baseName = _getBaseFileName(answerFile.path);
        answerFileMap[baseName] = answerFile;
      }

      List<LocalQuestionPair> newPairs = [];
      final now = DateTime.now();

      for (final questionFile in questionFiles) {
        if (_disposed) break;

        final baseName = _getBaseFileName(questionFile.path);
        final answerFile = answerFileMap[baseName];

        if (answerFile != null) {
          final questionStat = await questionFile.stat();
          final answerStat = await answerFile.stat();

          newPairs.add(LocalQuestionPair(
            baseName: baseName,
            questionFilePath: questionFile.path,
            answerFilePath: answerFile.path,
            questionFileName: path.basename(questionFile.path),
            answerFileName: path.basename(answerFile.path),
            questionFileSize: questionStat.size,
            answerFileSize: answerStat.size,
            createdAt: now,
            lastAccessed: now,
          ));
        }
      }

      if (newPairs.isNotEmpty && !_disposed) {
        await _localDb.insertQuestionPairs(newPairs);
        _showSuccessSnackBar(
            'Added ${newPairs.length} new question-answer pairs');
        await _loadQuestionPairs();
        await _loadDatabases();
      } else if (!_disposed) {
        _showSuccessSnackBar('No new matching question-answer pairs found');
      }
    } catch (e) {
      debugPrint('Error retrieving questions: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error retrieving questions: $e');
      }
    } finally {
      if (!_disposed) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isValidDocumentFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    return ['doc', 'docx', 'gnm', 'pdf', 'txt'].contains(extension);
  }

  String _getBaseFileName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex != -1 ? fileName.substring(0, lastDotIndex) : fileName;
  }

  bool _isMetadataValid() {
    return selectedStream != null &&
        selectedStream!.isNotEmpty &&
        selectedLevel != null &&
        selectedLevel!.isNotEmpty &&
        selectedTopic != null &&
        selectedTopic!.isNotEmpty &&
        selectedSubtopic != null &&
        selectedSubtopic!.isNotEmpty &&
        selectedLanguage != null &&
        selectedLanguage!.isNotEmpty &&
        selectedChapter != null &&
        selectedChapter!.isNotEmpty &&
        selectedType != null &&
        selectedType!.isNotEmpty;
  }

  Future<void> _addToQueue() async {
    if (selectedPair == null || _disposed) {
      _showErrorSnackBar('No question selected');
      return;
    }

    if (selectedPair!.questionPair.id == null) {
      _showErrorSnackBar('Invalid question pair - missing ID');
      return;
    }

    if (!_isMetadataValid()) {
      _showErrorSnackBar('Please fill all metadata fields');
      return;
    }

    if (uploadQueueCount >= 50) {
      _showErrorSnackBar('Upload queue is full (maximum 50 items)');
      return;
    }

    if (selectedPair!.isInQueue) {
      _showErrorSnackBar('This question is already in the upload queue');
      return;
    }

    try {
      final queueItem = UploadQueueItem(
        questionPairId: selectedPair!.questionPair.id!,
        stream: selectedStream ?? '',
        level: selectedLevel ?? '',
        topic: selectedTopic ?? '',
        subtopic: selectedSubtopic ?? '',
        language: selectedLanguage ?? '',
        chapter: selectedChapter ?? '',
        type: selectedType ?? '',
        createdAt: DateTime.now(),
      );

      await _localDb.addToUploadQueue(queueItem);
      if (!_disposed) {
        await _loadQuestionPairs();
        await _loadUploadQueueCount();
        await _loadDatabases();
        _showSuccessSnackBar('Added to upload queue');
        _clearMetadata();
      }
    } catch (e) {
      debugPrint('Error adding to queue: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error adding to queue: $e');
      }
    }
  }

  Future<void> _removeFromQueue() async {
    if (selectedPair?.queueItem == null || _disposed) return;

    try {
      await _localDb.removeFromUploadQueue(selectedPair!.queueItem!.id!);
      if (!_disposed) {
        await _loadQuestionPairs();
        await _loadUploadQueueCount();
        await _loadDatabases();
        _showSuccessSnackBar('Removed from upload queue');
        _clearMetadata();
      }
    } catch (e) {
      debugPrint('Error removing from queue: $e');
      if (!_disposed) {
        _showErrorSnackBar('Error removing from queue: $e');
      }
    }
  }

  void _cancelUpload() {
    _uploadSubscription?.cancel();
    _uploadCompleter?.complete();
    if (!_disposed && isUploading) {
      setState(() {
        isUploading = false;
        uploadProgress = 0.0;
        uploadStatus = 'Upload cancelled';
      });
    }
  }

  Future<void> _uploadQueue() async {
    if (uploadQueueCount == 0 || _disposed) {
      _showErrorSnackBar('Upload queue is empty');
      return;
    }

    if (isUploading) {
      _showErrorSnackBar('Upload already in progress');
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
      uploadStatus = 'Starting upload...';
      _currentUploadIndex = 0;
    });

    _uploadCompleter = Completer<void>();

    try {
      final queueItems = await _localDb.getUploadQueue();
      _totalUploadItems = queueItems.length;

      if (queueItems.isEmpty) {
        throw Exception('No items in upload queue');
      }

      int uploadedCount = 0;
      int errorCount = 0;
      List<String> errorMessages = [];

      // Process items one by one to prevent memory issues
      for (int i = 0; i < queueItems.length; i++) {
        if (_disposed || _uploadCompleter!.isCompleted) break;

        final queueItem = queueItems[i];
        _currentUploadIndex = i;

        if (!_disposed) {
          setState(() {
            uploadStatus = 'Uploading ${i + 1}/${queueItems.length}...';
            uploadProgress = i / queueItems.length;
          });
        }

        try {
          // Add small delay to prevent overwhelming the system
          await Future.delayed(const Duration(milliseconds: 100));

          final questionPair = questionPairs
              .firstWhere(
                  (pair) => pair.questionPair.id == queueItem.questionPairId)
              .questionPair;

          final question = QuestionModel(
            stream: queueItem.stream,
            level: queueItem.level,
            topic: queueItem.topic,
            subtopic: queueItem.subtopic,
            language: queueItem.language,
            chapter: queueItem.chapter,
            type: queueItem.type,
            questionFilePath: questionPair.questionFilePath,
            answerFilePath: questionPair.answerFilePath,
          );

          // Use the simplified upload method that doesn't have threading issues
          await _firebaseService.uploadQuestion(question).timeout(
                const Duration(minutes: 5),
                onTimeout: () => throw TimeoutException(
                    'Upload timeout', const Duration(minutes: 5)),
              );

          if (!_disposed) {
            await _localDb.incrementUploadCount(questionPair.id!);
            await _localDb.removeFromUploadQueue(queueItem.id!);
            uploadedCount++;

            // Update progress after each successful upload
            setState(() {
              uploadProgress = (i + 1) / queueItems.length;
            });
          }

          // Force garbage collection periodically
          if (i % 5 == 0) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } catch (e) {
          debugPrint('Upload error for item ${queueItem.questionPairId}: $e');
          errorCount++;
          errorMessages.add('Failed to upload ${queueItem.questionPairId}: $e');
          continue;
        }
      }

      if (!_disposed) {
        await _loadQuestionPairs();
        await _loadUploadQueueCount();
        await _loadDatabases();

        setState(() {
          uploadStatus = 'Upload completed!';
          uploadProgress = 1.0;
        });

        String message = 'Upload completed!\n';
        message += 'Successful: $uploadedCount\n';
        if (errorCount > 0) {
          message += 'Failed: $errorCount';
        }

        _showSuccessSnackBar(message);
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!_disposed) {
        _showErrorSnackBar('Upload failed: $e');
      }
    } finally {
      if (!_disposed) {
        setState(() {
          isUploading = false;
          uploadProgress = 0.0;
          uploadStatus = '';
        });
      }
      _uploadCompleter?.complete();
    }
  }

  Future<void> _showMetadataDialog(BuildContext context) async {
    if (selectedPair == null || _disposed) return;

    String? dialogStream = selectedStream;
    String? dialogLevel = selectedLevel;
    String? dialogTopic = selectedTopic;
    String? dialogSubtopic = selectedSubtopic;
    String? dialogLanguage = selectedLanguage;
    String? dialogChapter = selectedChapter;
    String? dialogType = selectedType;

    List<String> availableTopics = [];
    List<String> availableSubtopics = [];
    List<String> availableChapters = [];

    void updateAvailableOptions() {
      availableTopics = _metadataService.getTopicsForStream(dialogStream);
      availableSubtopics = _metadataService.getSubtopicsForTopic(dialogTopic);
      availableChapters = _metadataService.getChaptersForTopic(dialogTopic);
    }

    void validateAndClearInvalidSelections() {
      if (dialogTopic != null && !availableTopics.contains(dialogTopic)) {
        dialogTopic = null;
      }
      if (dialogSubtopic != null &&
          !availableSubtopics.contains(dialogSubtopic)) {
        dialogSubtopic = null;
      }
      if (dialogChapter != null && !availableChapters.contains(dialogChapter)) {
        dialogChapter = null;
      }
    }

    updateAvailableOptions();

    final result = await showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isValid() {
              return dialogStream != null &&
                  dialogLevel != null &&
                  dialogTopic != null &&
                  dialogSubtopic != null &&
                  dialogLanguage != null &&
                  dialogChapter != null &&
                  dialogType != null;
            }

            bool isHierarchyValid() {
              return _metadataService.isValidHierarchy(
                dialogStream,
                dialogTopic,
                dialogSubtopic,
                dialogChapter,
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure: ${selectedPair!.questionPair.baseName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 600,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (selectedPair!.questionPair.uploadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info,
                                  color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'This question has been uploaded ${selectedPair!.questionPair.uploadCount} times',
                                style: TextStyle(
                                    color: Colors.blue.shade700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_tree,
                                    color: Colors.amber.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Hierarchical Metadata',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Topics depend on streams, subtopics and chapters depend on topics.',
                              style: TextStyle(
                                  color: Colors.amber.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogStream,
                              decoration: const InputDecoration(
                                labelText: 'Stream *',
                                border: OutlineInputBorder(),
                                isDense: true,
                                helperText: 'Select exam stream first',
                              ),
                              items: _metadataService.streams.map((stream) {
                                return DropdownMenuItem(
                                    value: stream, child: Text(stream));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogStream = value;
                                        dialogTopic = null;
                                        dialogSubtopic = null;
                                        dialogChapter = null;
                                        updateAvailableOptions();
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogLevel,
                              decoration: const InputDecoration(
                                labelText: 'Level *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.levels.map((level) {
                                return DropdownMenuItem(
                                    value: level, child: Text(level));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogLevel = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: dialogTopic,
                        decoration: InputDecoration(
                          labelText: 'Subject/Topic *',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          helperText: dialogStream == null
                              ? 'Select a stream first'
                              : 'Available for ${dialogStream} (${availableTopics.length})',
                          enabled:
                              dialogStream != null && !selectedPair!.isInQueue,
                        ),
                        items: availableTopics.map((topic) {
                          return DropdownMenuItem(
                              value: topic, child: Text(topic));
                        }).toList(),
                        onChanged:
                            (dialogStream != null && !selectedPair!.isInQueue)
                                ? (value) {
                                    setDialogState(() {
                                      dialogTopic = value;
                                      dialogSubtopic = null;
                                      dialogChapter = null;
                                      updateAvailableOptions();
                                    });
                                  }
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogSubtopic,
                              decoration: InputDecoration(
                                labelText: 'Subtopic *',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                helperText: dialogTopic == null
                                    ? 'Select topic first'
                                    : '${availableSubtopics.length} available',
                                enabled: dialogTopic != null &&
                                    !selectedPair!.isInQueue,
                              ),
                              items: availableSubtopics.map((subtopic) {
                                return DropdownMenuItem(
                                    value: subtopic, child: Text(subtopic));
                              }).toList(),
                              onChanged: (dialogTopic != null &&
                                      !selectedPair!.isInQueue)
                                  ? (value) {
                                      setDialogState(() {
                                        dialogSubtopic = value;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogChapter,
                              decoration: InputDecoration(
                                labelText: 'Chapter *',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                helperText: dialogTopic == null
                                    ? 'Select topic first'
                                    : '${availableChapters.length} available',
                                enabled: dialogTopic != null &&
                                    !selectedPair!.isInQueue,
                              ),
                              items: availableChapters.map((chapter) {
                                return DropdownMenuItem(
                                    value: chapter, child: Text(chapter));
                              }).toList(),
                              onChanged: (dialogTopic != null &&
                                      !selectedPair!.isInQueue)
                                  ? (value) {
                                      setDialogState(() {
                                        dialogChapter = value;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogLanguage,
                              decoration: const InputDecoration(
                                labelText: 'Language *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.languages.map((language) {
                                return DropdownMenuItem(
                                    value: language, child: Text(language));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogLanguage = value;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogType,
                              decoration: const InputDecoration(
                                labelText: 'Question Type *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.types.map((type) {
                                return DropdownMenuItem(
                                    value: type, child: Text(type));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogType = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isValid() && isHierarchyValid()
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isValid() && isHierarchyValid()
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isValid() && isHierarchyValid()
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: isValid() && isHierarchyValid()
                                  ? Colors.green
                                  : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isValid() && isHierarchyValid()
                                    ? 'All metadata fields completed and hierarchy is valid'
                                    : !isValid()
                                        ? 'Please fill all metadata fields'
                                        : 'Invalid hierarchy: Please check your selections',
                                style: TextStyle(
                                  color: isValid() && isHierarchyValid()
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dialogStream != null && dialogTopic != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Hierarchy:',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$dialogStream → $dialogTopic',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (dialogSubtopic != null)
                                Text(
                                  '  ↳ Subtopic: $dialogSubtopic',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              if (dialogChapter != null)
                                Text(
                                  '  ↳ Chapter: $dialogChapter',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (selectedPair!.isInQueue) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.queue,
                                  color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This question is already in the upload queue with the metadata shown above',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (selectedPair!.isInQueue)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {'action': 'remove'});
                    },
                    icon: const Icon(Icons.remove_circle),
                    label: const Text('Remove from Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (!selectedPair!.isInQueue)
                  ElevatedButton.icon(
                    onPressed:
                        isValid() && isHierarchyValid() && uploadQueueCount < 50
                            ? () {
                                Navigator.pop(context, {
                                  'action': 'add',
                                  'stream': dialogStream,
                                  'level': dialogLevel,
                                  'topic': dialogTopic,
                                  'subtopic': dialogSubtopic,
                                  'language': dialogLanguage,
                                  'chapter': dialogChapter,
                                  'type': dialogType,
                                });
                              }
                            : null,
                    icon: const Icon(Icons.add_to_queue),
                    label: Text(uploadQueueCount >= 50
                        ? 'Queue Full'
                        : !isValid()
                            ? 'Complete Fields'
                            : !isHierarchyValid()
                                ? 'Fix Hierarchy'
                                : 'Add to Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValid() &&
                              isHierarchyValid() &&
                              uploadQueueCount < 50
                          ? Colors.green
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    if (result != null && !_disposed) {
      if (result['action'] == 'add') {
        setState(() {
          selectedStream = result['stream'];
          selectedLevel = result['level'];
          selectedTopic = result['topic'];
          selectedSubtopic = result['subtopic'];
          selectedLanguage = result['language'];
          selectedChapter = result['chapter'];
          selectedType = result['type'];
        });
        await _addToQueue();
      } else if (result['action'] == 'remove') {
        await _removeFromQueue();
      }
    }
  }

  Widget _buildOptimizedQuestionItem(int index) {
    final pair = filteredQuestionPairs[index];
    final isSelected = selectedPair == pair;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          pair.questionPair.baseName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uploaded: ${pair.questionPair.uploadCount} times',
              style: const TextStyle(fontSize: 11),
            ),
            if (pair.isInQueue)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'IN QUEUE',
                  style: TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
          ],
        ),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: pair.isInQueue ? Colors.green : Colors.grey,
          child: Text(
            '${pair.questionPair.uploadCount}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
        onTap: () {
          if (!_disposed) {
            setState(() {
              selectedPair = pair;
            });
            _loadMetadataFromQueue();
            _localDb.updateLastAccessed(pair.questionPair.id!);
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Bulk Upload Manager'),
            if (selectedDatabase != null) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.data_object,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      selectedDatabase!.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _showDatabaseSelector,
            icon: const Icon(Icons.storage),
            tooltip: 'Select Database',
          ),
          IconButton(
            onPressed: _showCreateDatabaseDialog,
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create New Database',
          ),
          if (isUploading)
            IconButton(
              onPressed: _cancelUpload,
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Cancel Upload',
            )
          else
            IconButton(
              onPressed: uploadQueueCount > 0
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear Queue'),
                          content: Text(
                              'Remove all $uploadQueueCount items from upload queue?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && !_disposed) {
                        await _localDb.clearUploadQueue();
                        await _loadQuestionPairs();
                        await _loadUploadQueueCount();
                        await _loadDatabases();
                        _showSuccessSnackBar('Upload queue cleared');
                      }
                    }
                  : null,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Upload Queue',
            ),
        ],
      ),
      body: selectedDatabase == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storage,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Database Selected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select an existing database or create a new one to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showDatabaseSelector,
                        icon: const Icon(Icons.storage),
                        label: const Text('Select Database'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateDatabaseDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Database'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Questions (${filteredQuestionPairs.length})',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: uploadQueueCount > 0
                                          ? Colors.blue
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Queue: $uploadQueueCount/50',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search questions...',
                                  prefixIcon:
                                      const Icon(Icons.search, size: 18),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : filteredQuestionPairs.isEmpty
                                  ? Center(
                                      child: Text(
                                        searchQuery.isNotEmpty
                                            ? 'No questions match your search.'
                                            : 'No questions found in this database.\nUse "Create New Database" to add questions.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      itemCount: filteredQuestionPairs.length,
                                      itemExtent: 80,
                                      physics: const BouncingScrollPhysics(),
                                      cacheExtent: 1000,
                                      addAutomaticKeepAlives: false,
                                      addRepaintBoundaries: false,
                                      itemBuilder: (context, index) {
                                        return _buildOptimizedQuestionItem(
                                            index);
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: selectedPair == null
                      ? const Center(
                          child: Text(
                            'Select a question to preview',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Preview: ${selectedPair!.questionPair.baseName}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (selectedPair!.isInQueue)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'IN QUEUE',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: isUploading
                                        ? null
                                        : () => _showMetadataDialog(context),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Configure'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: selectedPair!.isInQueue
                                          ? Colors.orange
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: DocumentViewer(
                                questionFilePath:
                                    selectedPair!.questionPair.questionFilePath,
                                answerFilePath:
                                    selectedPair!.questionPair.answerFilePath,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(
                                    top: BorderSide(
                                        color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.storage,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            selectedDatabase!.displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.blue,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.queue,
                                          color: uploadQueueCount > 0
                                              ? Colors.blue
                                              : Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Queue: $uploadQueueCount/50',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: uploadQueueCount > 0
                                                ? Colors.blue
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUploading) ...[
                                    Expanded(
                                      child: Column(
                                        children: [
                                          LinearProgressIndicator(
                                              value: uploadProgress),
                                          const SizedBox(height: 4),
                                          Text(
                                            uploadStatus,
                                            style:
                                                const TextStyle(fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton.icon(
                                      onPressed: _cancelUpload,
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Cancel'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                  if (uploadQueueCount > 0 && !isUploading)
                                    ElevatedButton.icon(
                                      onPressed: _uploadQueue,
                                      icon: const Icon(Icons.cloud_upload),
                                      label: Text('Upload ($uploadQueueCount)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  if (uploadQueueCount > 0 && !isUploading) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Clear Queue'),
                                            content: Text(
                                                'Remove all $uploadQueueCount items from upload queue?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Clear'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true && !_disposed) {
                                          await _localDb.clearUploadQueue();
                                          await _loadQuestionPairs();
                                          await _loadUploadQueueCount();
                                          await _loadDatabases();
                                          _showSuccessSnackBar(
                                              'Upload queue cleared');
                                        }
                                      },
                                      icon: const Icon(Icons.clear_all),
                                      tooltip: 'Clear Queue',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
