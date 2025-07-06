import 'package:flutter/material.dart';
import 'package:question_bank/service/background_conversion.dart';
import 'package:question_bank/service/doc_converter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'dart:io';

class PdfPreviewWidget extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfPreviewWidget({
    Key? key,
    required this.filePath,
    required this.title,
  }) : super(key: key);

  @override
  State<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<PdfPreviewWidget> {
  String? pdfPath;
  bool isLoading = true;
  String? errorMessage;
  late PdfViewerController _pdfViewerController;
  final BackgroundConversionService _conversionService =
      BackgroundConversionService();

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _checkForConvertedPdf();
  }

  Future<void> _checkForConvertedPdf() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // First check if already converted in background
    final cachedPath = _conversionService.getCachedConversion(widget.filePath);

    if (cachedPath != null) {
      // Already converted!
      setState(() {
        pdfPath = cachedPath;
        isLoading = false;
      });
      return;
    }

    // Check if currently being converted
    if (_conversionService.isConverting(widget.filePath)) {
      // Wait for background conversion to complete
      _waitForBackgroundConversion();
      return;
    }

    // Check if it's in queue
    if (_conversionService.isInQueue(widget.filePath)) {
      // Promote to immediate priority and wait
      _promoteAndWait();
      return;
    }

    // Not in system yet, convert immediately
    await _convertImmediately();
  }

  void _waitForBackgroundConversion() {
    setState(() {
      isLoading = true;
    });

    // Add completion listener
    _conversionService.addCompletionListener(
        widget.filePath, _onConversionComplete);

    // Add progress listener for better UX
    _conversionService.addProgressListener(
        widget.filePath, _onConversionProgress);
  }

  void _promoteAndWait() {
    setState(() {
      isLoading = true;
    });

    // This would be called by the parent when user switches questions
    // For now, just wait for conversion
    _conversionService.addCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.addProgressListener(
        widget.filePath, _onConversionProgress);
  }

  Future<void> _convertImmediately() async {
    setState(() {
      isLoading = true;
    });

    try {
      final convertedPath =
          await DocumentConverterService.convertToPdf(widget.filePath);

      if (mounted) {
        if (convertedPath != null && File(convertedPath).existsSync()) {
          setState(() {
            pdfPath = convertedPath;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = 'Failed to convert document to PDF';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error converting document: $e';
          isLoading = false;
        });
      }
    }
  }

  void _onConversionComplete(String? result) {
    if (mounted) {
      setState(() {
        pdfPath = result;
        isLoading = false;
        if (result == null) {
          errorMessage = 'Failed to convert document to PDF';
        }
      });
    }

    // Remove listeners
    _conversionService.removeCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.removeProgressListener(
        widget.filePath, _onConversionProgress);
  }

  void _onConversionProgress(ConversionProgress progress) {
    if (!mounted) return;

    switch (progress) {
      case ConversionProgress.queued:
        // Still in queue
        break;
      case ConversionProgress.started:
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
        break;
      case ConversionProgress.completed:
        // Will be handled by completion listener
        break;
      case ConversionProgress.failed:
        setState(() {
          isLoading = false;
          errorMessage = 'Conversion failed';
        });
        break;
    }
  }

  @override
  void dispose() {
    // Remove listeners
    _conversionService.removeCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.removeProgressListener(
        widget.filePath, _onConversionProgress);

    // Clean up the temporary PDF file when widget is disposed
    if (pdfPath != null && pdfPath != widget.filePath) {
      DocumentConverterService.cleanupTempPdfs([pdfPath!]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with file info and controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Icon(
                _getFileIcon(),
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          _getFileExtension(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusIndicator(),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLoading && pdfPath != null) ...[
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: () => _pdfViewerController.zoomLevel += 0.25,
                  tooltip: 'Zoom In',
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: () => _pdfViewerController.zoomLevel -= 0.25,
                  tooltip: 'Zoom Out',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _convertImmediately,
                  tooltip: 'Refresh',
                ),
              ],
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: _openInExternalApp,
                tooltip: 'Open in External App',
              ),
            ],
          ),
        ),

        // PDF Viewer or Loading/Error content
        Expanded(
          child: Container(
            width: double.infinity,
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    if (_conversionService.isConverting(widget.filePath)) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Converting...',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (_conversionService.isInQueue(widget.filePath)) {
      return Row(
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Queued',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (pdfPath != null) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 12,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Ready',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildContent() {
    if (isLoading) {
      return _buildLoadingWidget();
    }

    if (errorMessage != null) {
      return _buildErrorWidget();
    }

    if (pdfPath != null) {
      return _buildPdfViewer();
    }

    return _buildNoPreviewWidget();
  }

  Widget _buildLoadingWidget() {
    final isInBackground = _conversionService.isConverting(widget.filePath) ||
        _conversionService.isInQueue(widget.filePath);

    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isInBackground ? Colors.blue.shade600 : null,
            ),
            const SizedBox(height: 16),
            Text(
              isInBackground
                  ? 'Converting in background...'
                  : 'Converting document to PDF...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isInBackground
                  ? 'Your document is being processed while you browse'
                  : 'This may take a moment for large files',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview Not Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _convertImmediately,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openInExternalApp,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Externally'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SfPdfViewer.file(
        File(pdfPath!),
        controller: _pdfViewerController,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Document loaded: ${details.document.pages.count} pages'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          setState(() {
            errorMessage = 'Failed to load PDF: ${details.error}';
            pdfPath = null;
          });
        },
      ),
    );
  }

  Widget _buildNoPreviewWidget() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Preview Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This file type cannot be previewed',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openInExternalApp,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = _getFileExtension().toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'gnm':
        return Icons.grid_on;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileExtension() {
    return widget.filePath.split('.').last.toUpperCase();
  }

  void _openInExternalApp() {
    try {
      if (Platform.isWindows) {
        Process.run('start', ['', widget.filePath], runInShell: true);
      } else if (Platform.isMacOS) {
        Process.run('open', [widget.filePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [widget.filePath]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
