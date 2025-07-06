import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:question_bank/question_model.dart';
import 'package:question_bank/screens/bulk_upload_screen.dart';
import 'package:question_bank/service/firebase_service.dart';
import 'package:question_bank/service/metadata_service.dart';
import 'package:question_bank/widget/medta_datawidegt.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  final MetadataService _metadataService = MetadataService();

  final _formKey = GlobalKey<FormState>();

  String? selectedStream;
  String? selectedLevel;
  String? selectedTopic;
  String? selectedSubtopic;
  String? selectedLanguage;
  String? selectedChapter;
  String? selectedType;

  String? questionFilePath;
  String? answerFilePath;

  bool isUploading = false;

  List<QuestionModel> uploadedQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _loadQuestions();
  }

  Future<void> _loadMetadata() async {
    await _metadataService.loadAllMetadata();
    setState(() {});
  }

  Future<void> _loadQuestions() async {
    final questions = await _firebaseService.getAllQuestions();
    setState(() {
      uploadedQuestions = questions;
    });
  }

  Future<void> _selectQuestionFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx', 'GNM'],
    );

    if (result != null) {
      setState(() {
        questionFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _selectAnswerFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx', 'GNM'],
    );

    if (result != null) {
      setState(() {
        answerFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _uploadQuestion() async {
    if (_formKey.currentState!.validate() &&
        questionFilePath != null &&
        answerFilePath != null) {
      setState(() {
        isUploading = true;
      });

      try {
        // Check if question with same metadata already exists
        final isDuplicate = await _firebaseService.questionExistsWithMetadata(
          stream: selectedStream!,
          level: selectedLevel!,
          topic: selectedTopic!,
          subtopic: selectedSubtopic!,
          language: selectedLanguage!,
          chapter: selectedChapter!,
          type: selectedType!,
        );

        if (isDuplicate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'A question with the same metadata already exists. Upload skipped.'),
            ),
          );
          _resetForm();
          return;
        }

        final question = QuestionModel(
          stream: selectedStream!,
          level: selectedLevel!,
          topic: selectedTopic!,
          subtopic: selectedSubtopic!,
          language: selectedLanguage!,
          chapter: selectedChapter!,
          type: selectedType!,
          questionFilePath: questionFilePath!,
          answerFilePath: answerFilePath!,
        );

        await _firebaseService.uploadQuestion(question);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question uploaded successfully!')),
        );

        _resetForm();
        await _loadQuestions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading question: $e')),
        );
      } finally {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      selectedStream = null;
      selectedLevel = null;
      selectedTopic = null;
      selectedSubtopic = null;
      selectedLanguage = null;
      selectedChapter = null;
      selectedType = null;
      questionFilePath = null;
      answerFilePath = null;
    });
  }

  void _openBulkUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BulkUploadScreen(),
      ),
    ).then((_) {
      // Refresh questions list when returning from bulk upload
      _loadQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank Admin Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Bulk Upload Button in AppBar
          IconButton(
            onPressed: _openBulkUpload,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel - Upload Form
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Upload New Question',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Bulk Upload Button
                    ElevatedButton.icon(
                      onPressed: _openBulkUpload,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Bulk Upload Questions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider(),
                    const SizedBox(height: 20),

                    const Text(
                      'Single Question Upload',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Stream Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStream,
                      decoration: const InputDecoration(
                        labelText: 'Stream',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.streams.map((stream) {
                        return DropdownMenuItem(
                          value: stream,
                          child: Text(stream),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStream = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a stream' : null,
                    ),
                    const SizedBox(height: 16),

                    // Level Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedLevel,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.levels.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLevel = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a level' : null,
                    ),
                    const SizedBox(height: 16),

                    // Topic Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedTopic,
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.topics.map((topic) {
                        return DropdownMenuItem(
                          value: topic,
                          child: Text(topic),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTopic = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a topic' : null,
                    ),
                    const SizedBox(height: 16),

                    // Subtopic Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedSubtopic,
                      decoration: const InputDecoration(
                        labelText: 'Subtopic',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.subtopics.map((subtopic) {
                        return DropdownMenuItem(
                          value: subtopic,
                          child: Text(subtopic),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSubtopic = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a subtopic' : null,
                    ),
                    const SizedBox(height: 16),

                    // Language Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedLanguage,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.languages.map((language) {
                        return DropdownMenuItem(
                          value: language,
                          child: Text(language),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLanguage = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a language' : null,
                    ),
                    const SizedBox(height: 16),

                    // Chapter Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedChapter,
                      decoration: const InputDecoration(
                        labelText: 'Chapter',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.chapters.map((chapter) {
                        return DropdownMenuItem(
                          value: chapter,
                          child: Text(chapter),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedChapter = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a chapter' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _metadataService.types.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a type' : null,
                    ),
                    const SizedBox(height: 20),

                    // Question File Selection
                    Card(
                      child: ListTile(
                        title: Text(questionFilePath != null
                            ? 'Question: ${questionFilePath!.split('\\').last}'
                            : 'Select Question File'),
                        leading: const Icon(Icons.file_present),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _selectQuestionFile,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Answer File Selection
                    Card(
                      child: ListTile(
                        title: Text(answerFilePath != null
                            ? 'Answer: ${answerFilePath!.split('\\').last}'
                            : 'Select Answer File'),
                        leading: const Icon(Icons.file_present),
                        trailing: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _selectAnswerFile,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload Button
                    ElevatedButton(
                      onPressed: isUploading ? null : _uploadQuestion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isUploading
                          ? const CircularProgressIndicator()
                          : const Text('Upload Question',
                              style: TextStyle(fontSize: 16)),
                    ),

                    const SizedBox(height: 20),

                    // Metadata Manager Button
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: SizedBox(
                              width: 800,
                              height: 600,
                              child: MetadataManager(
                                onMetadataUpdated: _loadMetadata,
                              ),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Manage Metadata'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Panel - Uploaded Questions
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Uploaded Questions',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: ${uploadedQuestions.length}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: uploadedQuestions.isEmpty
                        ? const Center(child: Text('No questions uploaded yet'))
                        : ListView.builder(
                            itemCount: uploadedQuestions.length,
                            itemBuilder: (context, index) {
                              final question = uploadedQuestions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                      'Question ID: ${question.questionId}'),
                                  subtitle: Text(
                                    'Stream: ${question.stream} | Level: ${question.level} | '
                                    'Topic: ${question.topic} | Type: ${question.type}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      await _firebaseService
                                          .deleteQuestion(question.questionId!);
                                      await _loadQuestions();
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
          ),
        ],
      ),
    );
  }
}
