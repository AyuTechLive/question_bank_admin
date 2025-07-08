import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:question_bank/service/local_db.dart';
import 'package:question_bank/service/metadata_service.dart';
import 'package:question_bank/service/firebase_service.dart';
import 'package:question_bank/question_model.dart';
import 'package:question_bank/widget/doc_viewer.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class EnhancedBulkUploadScreen extends StatefulWidget {
  const EnhancedBulkUploadScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedBulkUploadScreen> createState() =>
      _EnhancedBulkUploadScreenState();
}

class _EnhancedBulkUploadScreenState extends State<EnhancedBulkUploadScreen> {
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
  double uploadProgress = 0.0;
  String uploadStatus = '';
  int uploadQueueCount = 0;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    _loadMetadata();
    _loadDatabases();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _filterQuestions();
    });
  }

  void _filterQuestions() {
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
    await _metadataService.loadAllMetadata();
    setState(() {});
  }

  Future<void> _loadDatabases() async {
    setState(() {
      isLoading = true;
    });

    try {
      final dbs = await _localDb.getAllDatabases();
      setState(() {
        databases = dbs;
        if (databases.isNotEmpty && selectedDatabase == null) {
          // Auto-select the most recently accessed database
          selectedDatabase = databases.first;
          _selectDatabase(selectedDatabase!);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading databases: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDatabase(DatabaseInfo database) async {
    setState(() {
      isLoading = true;
      selectedDatabase = database;
    });

    try {
      await _localDb.selectDatabase(database.databaseName);
      await _loadQuestionPairs();
      await _loadUploadQueueCount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting database: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadQuestionPairs() async {
    if (selectedDatabase == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final pairs = await _localDb.getQuestionPairsWithQueue();

      setState(() {
        questionPairs = pairs;
        _filterQuestions();
        if (questionPairs.isNotEmpty && selectedPair == null) {
          selectedPair = questionPairs.first;
          _loadMetadataFromQueue();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading question pairs: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUploadQueueCount() async {
    final count = await _localDb.getUploadQueueCount();
    setState(() {
      uploadQueueCount = count;
    });
  }

  void _loadMetadataFromQueue() {
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

  Future<void> _showCreateDatabaseDialog() async {
    String? questionsFolder = await FilePicker.platform.getDirectoryPath();
    if (questionsFolder == null) return;

    String? answersFolder = await FilePicker.platform.getDirectoryPath();
    if (answersFolder == null) return;

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

    if (result != null && result.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      try {
        await _localDb.createNewDatabase(
          displayName: result,
          questionsFolder: questionsFolder,
          answersFolder: answersFolder,
        );

        await _loadDatabases();

        // Select the newly created database
        final newDb = databases.firstWhere(
          (db) => db.displayName == result,
        );
        await _selectDatabase(newDb);

        // Load questions from the folders
        await _retrieveQuestions(questionsFolder, answersFolder);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database "$result" created successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating database: $e')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showDatabaseSelector() async {
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
                // Create new database button
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

                // Existing databases list
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
    setState(() {
      isLoading = true;
    });

    try {
      final questionsDir = Directory(questionsPath);
      final answersDir = Directory(answersPath);

      if (!questionsDir.existsSync() || !answersDir.existsSync()) {
        throw Exception('One or both folders do not exist');
      }

      // Get all files from directories
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

      // Create answer file map
      final Map<String, File> answerFileMap = {};
      for (final answerFile in answerFiles) {
        final baseName = _getBaseFileName(answerFile.path);
        answerFileMap[baseName] = answerFile;
      }

      // Match question and answer files
      List<LocalQuestionPair> newPairs = [];
      final now = DateTime.now();

      for (final questionFile in questionFiles) {
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

      if (newPairs.isNotEmpty) {
        // Insert new pairs into local database
        await _localDb.insertQuestionPairs(newPairs);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newPairs.length} new question-answer pairs'),
          ),
        );

        // Reload the question pairs and databases
        await _loadQuestionPairs();
        await _loadDatabases();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No new matching question-answer pairs found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error retrieving questions: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
    if (selectedPair == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No question selected')),
      );
      return;
    }

    if (selectedPair!.questionPair.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid question pair - missing ID')),
      );
      return;
    }

    if (!_isMetadataValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all metadata fields')),
      );
      return;
    }

    if (uploadQueueCount >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Upload queue is full (maximum 50 items)')),
      );
      return;
    }

    if (selectedPair!.isInQueue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This question is already in the upload queue')),
      );
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
      await _loadQuestionPairs();
      await _loadUploadQueueCount();
      await _loadDatabases(); // Refresh database stats

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to upload queue')),
      );

      _clearMetadata();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to queue: $e')),
      );
      debugPrint('Error adding to queue: $e');
    }
  }

  Future<void> _removeFromQueue() async {
    if (selectedPair?.queueItem == null) return;

    try {
      await _localDb.removeFromUploadQueue(selectedPair!.queueItem!.id!);
      await _loadQuestionPairs();
      await _loadUploadQueueCount();
      await _loadDatabases(); // Refresh database stats

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from upload queue')),
      );

      _clearMetadata();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing from queue: $e')),
      );
    }
  }

  Future<void> _uploadQueue() async {
    if (uploadQueueCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload queue is empty')),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
      uploadStatus = 'Starting upload...';
    });

    try {
      final queueItems = await _localDb.getUploadQueue();
      int uploadedCount = 0;
      int errorCount = 0;
      List<String> errorMessages = [];

      for (int i = 0; i < queueItems.length; i++) {
        final queueItem = queueItems[i];

        setState(() {
          uploadStatus = 'Uploading ${i + 1}/${queueItems.length}...';
          uploadProgress = (i + 1) / queueItems.length;
        });

        try {
          // Find the corresponding question pair
          final questionPair = questionPairs
              .firstWhere(
                  (pair) => pair.questionPair.id == queueItem.questionPairId)
              .questionPair;

          // Create question model
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

          // Upload the question
          await _firebaseService.uploadQuestion(question);

          // Increment upload count in local DB
          await _localDb.incrementUploadCount(questionPair.id!);

          // Remove from upload queue
          await _localDb.removeFromUploadQueue(queueItem.id!);

          uploadedCount++;
        } catch (e) {
          errorCount++;
          errorMessages.add('Failed to upload ${queueItem.questionPairId}: $e');
          continue;
        }
      }

      await _loadQuestionPairs();
      await _loadUploadQueueCount();
      await _loadDatabases(); // Refresh database stats

      setState(() {
        uploadStatus = 'Upload completed!';
        uploadProgress = 1.0;
      });

      String message = 'Upload completed!\n';
      message += 'Successful: $uploadedCount\n';
      if (errorCount > 0) {
        message += 'Failed: $errorCount';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
        uploadProgress = 0.0;
        uploadStatus = '';
      });
    }
  }

  Future<void> _showMetadataDialog(BuildContext context) async {
    if (selectedPair == null) return;

    // Load existing metadata if in queue
    String? dialogStream = selectedStream;
    String? dialogLevel = selectedLevel;
    String? dialogTopic = selectedTopic;
    String? dialogSubtopic = selectedSubtopic;
    String? dialogLanguage = selectedLanguage;
    String? dialogChapter = selectedChapter;
    String? dialogType = selectedType;

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
              content: Container(
                width: 600,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Upload count info
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

                      // Row 1: Stream and Level
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogStream,
                              decoration: const InputDecoration(
                                labelText: 'Stream',
                                border: OutlineInputBorder(),
                                isDense: true,
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
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogLevel,
                              decoration: const InputDecoration(
                                labelText: 'Level',
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

                      // Row 2: Topic and Subtopic
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogTopic,
                              decoration: const InputDecoration(
                                labelText: 'Topic',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.topics.map((topic) {
                                return DropdownMenuItem(
                                    value: topic, child: Text(topic));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogTopic = value;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogSubtopic,
                              decoration: const InputDecoration(
                                labelText: 'Subtopic',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.subtopics.map((subtopic) {
                                return DropdownMenuItem(
                                    value: subtopic, child: Text(subtopic));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogSubtopic = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Language and Chapter
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dialogLanguage,
                              decoration: const InputDecoration(
                                labelText: 'Language',
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
                              value: dialogChapter,
                              decoration: const InputDecoration(
                                labelText: 'Chapter',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _metadataService.chapters.map((chapter) {
                                return DropdownMenuItem(
                                    value: chapter, child: Text(chapter));
                              }).toList(),
                              onChanged: selectedPair!.isInQueue
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        dialogChapter = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 4: Type (full width)
                      DropdownButtonFormField<String>(
                        value: dialogType,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
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
                      const SizedBox(height: 20),

                      // Validation Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isValid()
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isValid()
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isValid() ? Icons.check_circle : Icons.warning,
                              color: isValid() ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isValid()
                                    ? 'All metadata fields completed'
                                    : 'Please fill all metadata fields',
                                style: TextStyle(
                                  color: isValid()
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

                      // Queue status for existing items
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
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                // Remove from Queue (if in queue)
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

                // Add to Queue (if not in queue and valid)
                if (!selectedPair!.isInQueue)
                  ElevatedButton.icon(
                    onPressed: isValid() && uploadQueueCount < 50
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
                    label: Text(
                        uploadQueueCount >= 50 ? 'Queue Full' : 'Add to Queue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValid() && uploadQueueCount < 50
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

    // Handle dialog result
    if (result != null) {
      if (result['action'] == 'add') {
        // Update local state
        setState(() {
          selectedStream = result['stream'];
          selectedLevel = result['level'];
          selectedTopic = result['topic'];
          selectedSubtopic = result['subtopic'];
          selectedLanguage = result['language'];
          selectedChapter = result['chapter'];
          selectedType = result['type'];
        });

        // Add to queue
        await _addToQueue();
      } else if (result['action'] == 'remove') {
        // Remove from queue
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
          setState(() {
            selectedPair = pair;
          });
          _loadMetadataFromQueue();
          _localDb.updateLastAccessed(pair.questionPair.id!);
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
          // Database selector button
          IconButton(
            onPressed: _showDatabaseSelector,
            icon: const Icon(Icons.storage),
            tooltip: 'Select Database',
          ),
          // Create new database button
          IconButton(
            onPressed: _showCreateDatabaseDialog,
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create New Database',
          ),
          // Clear queue button
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

                    if (confirm == true) {
                      await _localDb.clearUploadQueue();
                      await _loadQuestionPairs();
                      await _loadUploadQueueCount();
                      await _loadDatabases();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Upload queue cleared')),
                      );
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
                // Left Panel - Questions List
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Column(
                      children: [
                        // Header with Search
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
                              // Title and Queue Count
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
                              // Search Bar
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

                        // Questions List with Optimized Scrolling
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
                                      itemExtent:
                                          80, // Fixed height for better performance
                                      physics: const BouncingScrollPhysics(),
                                      cacheExtent:
                                          1000, // Cache more items for smoother scrolling
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

                // Right Panel - Preview and Configuration
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
                            // Preview Header
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
                                    onPressed: () =>
                                        _showMetadataDialog(context),
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

                            // Document Viewer
                            Expanded(
                              child: DocumentViewer(
                                questionFilePath:
                                    selectedPair!.questionPair.questionFilePath,
                                answerFilePath:
                                    selectedPair!.questionPair.answerFilePath,
                              ),
                            ),

                            // Bottom Action Bar
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
                                  // Database Info
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

                                  // Upload Progress
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
                                  ],

                                  // Upload Queue Button
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

                                  // Clear Queue Button
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

                                        if (confirm == true) {
                                          await _localDb.clearUploadQueue();
                                          await _loadQuestionPairs();
                                          await _loadUploadQueueCount();
                                          await _loadDatabases();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Upload queue cleared')),
                                          );
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
