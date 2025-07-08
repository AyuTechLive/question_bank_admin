import 'package:flutter/material.dart';
import 'package:question_bank/service/background_conversion.dart';
import 'package:question_bank/widget/pdf_preview.dart';

import 'dart:io';

class DocumentViewer extends StatefulWidget {
  final String questionFilePath;
  final String answerFilePath;
  final int? questionPairId; // Add question pair ID for caching

  const DocumentViewer({
    Key? key,
    required this.questionFilePath,
    required this.answerFilePath,
    this.questionPairId,
  }) : super(key: key);

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  bool showingQuestion = true;
  final BackgroundConversionService _conversionService =
      BackgroundConversionService();

  String get currentFilePath =>
      showingQuestion ? widget.questionFilePath : widget.answerFilePath;
  String get currentFileName =>
      currentFilePath.split(Platform.pathSeparator).last;
  String get otherFilePath =>
      showingQuestion ? widget.answerFilePath : widget.questionFilePath;

  @override
  void initState() {
    super.initState();
    // When user is viewing one document, start converting the other in background
    _startOtherFileConversion();
  }

  void _startOtherFileConversion() {
    // If user is viewing question, prioritize answer conversion and vice versa
    // This ensures when they switch, the other file is ready
    final List<dynamic> mockQuestionModels = [
      _MockQuestionModel(widget.questionFilePath, widget.answerFilePath)
    ];
    _conversionService.startBatchConversion(mockQuestionModels, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle Buttons
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      showingQuestion = true;
                    });
                    // Promote answer file conversion when switching to question
                    _promoteOtherFileConversion();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: showingQuestion ? Colors.blue : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Question',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                showingQuestion ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFileStatusIcon(
                            widget.questionFilePath, showingQuestion),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      showingQuestion = false;
                    });
                    // Promote question file conversion when switching to answer
                    _promoteOtherFileConversion();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          !showingQuestion ? Colors.orange : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Answer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                !showingQuestion ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFileStatusIcon(
                            widget.answerFilePath, !showingQuestion),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // PDF Preview Content with question pair ID
        Expanded(
          child: PdfPreviewWidget(
            key:
                ValueKey(currentFilePath), // Force rebuild when switching files
            filePath: currentFilePath,
            title: currentFileName,
            questionPairId:
                widget.questionPairId, // Pass question pair ID for caching
          ),
        ),
      ],
    );
  }

  Widget _buildFileStatusIcon(String filePath, bool isCurrentlyShowing) {
    if (isCurrentlyShowing) {
      return const SizedBox
          .shrink(); // Don't show status for currently displayed file
    }

    if (_conversionService.getCachedConversion(filePath) != null) {
      return Icon(
        Icons.check_circle,
        size: 16,
        color: Colors.green.shade600,
      );
    } else if (_conversionService.isConverting(filePath)) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.blue.shade600,
        ),
      );
    } else if (_conversionService.isInQueue(filePath)) {
      return Icon(
        Icons.schedule,
        size: 16,
        color: Colors.orange.shade600,
      );
    }

    return const SizedBox.shrink();
  }

  void _promoteOtherFileConversion() {
    // When user switches views, ensure the background file gets priority
    final List<dynamic> mockQuestionModels = [
      _MockQuestionModel(widget.questionFilePath, widget.answerFilePath)
    ];
    _conversionService.updateCurrentQuestion(mockQuestionModels, 0);
  }
}

// Mock class to work with the background conversion service
class _MockQuestionModel {
  final _MockFile questionFile;
  final _MockFile answerFile;

  _MockQuestionModel(String questionPath, String answerPath)
      : questionFile = _MockFile(questionPath),
        answerFile = _MockFile(answerPath);
}

class _MockFile {
  final String path;
  _MockFile(this.path);
}
