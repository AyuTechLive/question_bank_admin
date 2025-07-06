import 'package:flutter/material.dart';
import 'package:question_bank/model/question_metadata_model.dart';

import 'package:question_bank/question_model.dart';
import 'package:question_bank/service/background_conversion.dart';
import 'package:question_bank/service/firebase_service.dart';
import 'package:question_bank/service/metadata_service.dart';

import 'package:question_bank/widget/doc_viewer.dart';

import 'package:question_bank/widget/question_metadata_form.dart';

class BulkUploadPreviewScreen extends StatefulWidget {
  final List<QuestionMetadataModel> questionModels;

  const BulkUploadPreviewScreen({
    Key? key,
    required this.questionModels,
  }) : super(key: key);

  @override
  State<BulkUploadPreviewScreen> createState() =>
      _BulkUploadPreviewScreenState();
}

class _BulkUploadPreviewScreenState extends State<BulkUploadPreviewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final MetadataService _metadataService = MetadataService();
  final BackgroundConversionService _conversionService =
      BackgroundConversionService();

  int selectedQuestionIndex = 0;
  bool isUploading = false;
  double uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _startBackgroundConversion();
  }

  @override
  void dispose() {
    _conversionService.clear();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    await _metadataService.loadAllMetadata();
    setState(() {});
  }

  void _startBackgroundConversion() {
    // Start background conversion for all questions
    _conversionService.startBatchConversion(
        widget.questionModels, selectedQuestionIndex);
  }

  Future<void> _bulkUpload() async {
    // Validate all questions have complete metadata
    final invalidQuestions = widget.questionModels
        .asMap()
        .entries
        .where((entry) => !entry.value.isValid)
        .map((entry) => entry.key + 1)
        .toList();

    if (invalidQuestions.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all metadata for questions: ${invalidQuestions.join(', ')}',
          ),
        ),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });

    try {
      // Upload files (skip duplicates silently)
      int uploadedCount = 0;
      for (int i = 0; i < widget.questionModels.length; i++) {
        final model = widget.questionModels[i];

        // Check if question with same metadata already exists
        final isDuplicate = await _firebaseService.questionExistsWithMetadata(
          stream: model.stream!,
          level: model.level!,
          topic: model.topic!,
          subtopic: model.subtopic!,
          language: model.language!,
          chapter: model.chapter!,
          type: model.type!,
        );

        if (!isDuplicate) {
          final question = QuestionModel(
            stream: model.stream!,
            level: model.level!,
            topic: model.topic!,
            subtopic: model.subtopic!,
            language: model.language!,
            chapter: model.chapter!,
            type: model.type!,
            questionFilePath: model.questionFile.path,
            answerFilePath: model.answerFile.path,
          );

          await _firebaseService.uploadQuestion(question);
          uploadedCount++;
        }
        // If duplicate, silently skip without any notification

        setState(() {
          uploadProgress = (i + 1) / widget.questionModels.length;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully processed ${widget.questionModels.length} questions! ($uploadedCount uploaded)'),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading questions: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
        uploadProgress = 0.0;
      });
    }
  }

  void _copyMetadataToAll() {
    final currentQuestion = widget.questionModels[selectedQuestionIndex];
    if (!currentQuestion.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please fill all metadata for the current question first'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Metadata'),
        content: Text(
          'Copy metadata from "${currentQuestion.baseName}" to all other questions?\n\n'
          'This will overwrite existing metadata in other questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (int i = 0; i < widget.questionModels.length; i++) {
                  if (i != selectedQuestionIndex) {
                    widget.questionModels[i].copyMetadataFrom(currentQuestion);
                  }
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Metadata copied to all questions'),
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  int get validQuestionsCount {
    return widget.questionModels.where((q) => q.isValid).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Questions'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Conversion Status Indicator
          //  _buildConversionStatusIndicator(),
          IconButton(
            onPressed: _copyMetadataToAll,
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy current question metadata to all',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel - Questions List and Current Question Form
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: $validQuestionsCount/${widget.questionModels.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: _copyMetadataToAll,
                          icon: const Icon(Icons.copy_all, size: 16),
                          label: const Text('Copy to All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Questions List
                  const Text(
                    'Questions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: widget.questionModels.length,
                      itemBuilder: (context, index) {
                        final model = widget.questionModels[index];
                        final isSelected = index == selectedQuestionIndex;
                        final isComplete = model.isValid;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          color: isSelected
                              ? Colors.blue.shade100
                              : isComplete
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                          child: ListTile(
                            title: Text(
                              model.baseName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('Question ${index + 1}'),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Colors.blue
                                  : isComplete
                                      ? Colors.green
                                      : Colors.red,
                              child: isComplete
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                            ),
                            trailing: isComplete
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.warning, color: Colors.red),
                            onTap: () {
                              setState(() {
                                selectedQuestionIndex = index;
                              });
                              // Update background conversion priorities when user changes question
                              _conversionService.updateCurrentQuestion(
                                  widget.questionModels, index);
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Current Question Metadata Form
                  const Text(
                    'Current Question Metadata',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    flex: 2,
                    child: QuestionMetadataForm(
                      questionModel:
                          widget.questionModels[selectedQuestionIndex],
                      metadataService: _metadataService,
                      onMetadataChanged: () {
                        setState(() {}); // Refresh to update validation status
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Upload Progress
                  if (isUploading) ...[
                    LinearProgressIndicator(value: uploadProgress),
                    const SizedBox(height: 10),
                    Text(
                      'Uploading... ${(uploadProgress * 100).toInt()}%',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Upload Button
                  ElevatedButton(
                    onPressed: isUploading ? null : _bulkUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          validQuestionsCount == widget.questionModels.length
                              ? Colors.green
                              : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Upload ${widget.questionModels.length} Questions',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Right Panel - Document Viewer
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Preview: ${widget.questionModels[selectedQuestionIndex].baseName}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Document Display Area
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DocumentViewer(
                        questionFilePath: widget
                            .questionModels[selectedQuestionIndex]
                            .questionFile
                            .path,
                        answerFilePath: widget
                            .questionModels[selectedQuestionIndex]
                            .answerFile
                            .path,
                      ),
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
