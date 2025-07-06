import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:question_bank/model/question_metadata_model.dart';

import 'dart:io';

import 'package:question_bank/screens/bulk_upload_preview.dart';

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({Key? key}) : super(key: key);

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  String? questionsFolderPath;
  String? answersFolderPath;
  List<QuestionMetadataModel> questionModels = [];
  List<QuestionMetadataModel> selectedQuestions = [];
  bool isLoading = false;

  Future<void> _selectQuestionsFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        questionsFolderPath = selectedDirectory;
      });
    }
  }

  Future<void> _selectAnswersFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        answersFolderPath = selectedDirectory;
      });
    }
  }

  Future<void> _retrieveQuestions() async {
    if (questionsFolderPath == null || answersFolderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both folders first')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final questionsDir = Directory(questionsFolderPath!);
      final answersDir = Directory(answersFolderPath!);

      if (!questionsDir.existsSync() || !answersDir.existsSync()) {
        throw Exception('One or both folders do not exist');
      }

      // Get all files from questions directory
      final questionFiles = questionsDir
          .listSync()
          .where((file) => file is File && _isValidDocumentFile(file.path))
          .cast<File>()
          .toList();

      // Get all files from answers directory
      final answerFiles = answersDir
          .listSync()
          .where((file) => file is File && _isValidDocumentFile(file.path))
          .cast<File>()
          .toList();

      // Create a map of answer files by their base name
      final Map<String, File> answerFileMap = {};
      for (final answerFile in answerFiles) {
        final baseName = _getBaseFileName(answerFile.path);
        answerFileMap[baseName] = answerFile;
      }

      // Match question files with answer files
      List<QuestionMetadataModel> models = [];
      for (final questionFile in questionFiles) {
        final baseName = _getBaseFileName(questionFile.path);
        final answerFile = answerFileMap[baseName];

        if (answerFile != null) {
          models.add(QuestionMetadataModel(
            questionFile: questionFile,
            answerFile: answerFile,
            baseName: baseName,
          ));
        }
      }

      setState(() {
        questionModels = models;
        selectedQuestions.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Found ${models.length} matching question-answer pairs')),
      );
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
    return ['doc', 'docx', 'gnm'].contains(extension);
  }

  String _getBaseFileName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex != -1 ? fileName.substring(0, lastDotIndex) : fileName;
  }

  void _toggleSelection(QuestionMetadataModel model) {
    setState(() {
      if (selectedQuestions.contains(model)) {
        selectedQuestions.remove(model);
      } else {
        if (selectedQuestions.length < 20) {
          selectedQuestions.add(model);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Maximum 20 questions can be selected')),
          );
        }
      }
    });
  }

  void _proceedToPreview() {
    if (selectedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one question')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkUploadPreviewScreen(
          questionModels: selectedQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Upload Questions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulk Upload Questions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Folder Selection Cards
            Card(
              child: ListTile(
                title: Text(questionsFolderPath != null
                    ? 'Questions Folder: ${questionsFolderPath!.split(Platform.pathSeparator).last}'
                    : 'Select Questions Folder'),
                leading: const Icon(Icons.folder),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _selectQuestionsFolder,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Card(
              child: ListTile(
                title: Text(answersFolderPath != null
                    ? 'Answers Folder: ${answersFolderPath!.split(Platform.pathSeparator).last}'
                    : 'Select Answers Folder'),
                leading: const Icon(Icons.folder),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _selectAnswersFolder,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Retrieve Button
            ElevatedButton(
              onPressed: isLoading ? null : _retrieveQuestions,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Retrieve Questions',
                      style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),

            // Selection Info
            if (questionModels.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${questionModels.length} question-answer pairs',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Selected: ${selectedQuestions.length}/20',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selectedQuestions.length == 20
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Questions List
            Expanded(
              child: questionModels.isEmpty
                  ? const Center(
                      child: Text(
                        'No questions found. Please select folders and click "Retrieve Questions".',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: questionModels.length,
                      itemBuilder: (context, index) {
                        final model = questionModels[index];
                        final isSelected = selectedQuestions.contains(model);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(model),
                            ),
                            title: Text(model.baseName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Question: ${model.questionFile.path.split(Platform.pathSeparator).last}'),
                                Text(
                                    'Answer: ${model.answerFile.path.split(Platform.pathSeparator).last}'),
                              ],
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? Colors.green : Colors.grey,
                            ),
                            onTap: () => _toggleSelection(model),
                          ),
                        );
                      },
                    ),
            ),

            // Proceed Button
            if (selectedQuestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceedToPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  'Configure ${selectedQuestions.length} Questions',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
