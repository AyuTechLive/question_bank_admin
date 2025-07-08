import 'package:flutter/material.dart';
import 'package:question_bank/service/background_conversion.dart';
import 'package:question_bank/service/doc_converter.dart';
import 'package:question_bank/service/local_db.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'dart:io';

class PdfPreviewWidget extends StatefulWidget {
  final String filePath;
  final String title;
  final int? questionPairId; // For updating local DB with PDF paths

  const PdfPreviewWidget({
    Key? key,
    required this.filePath,
    required this.title,
    this.questionPairId,
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
  final LocalDatabaseService _localDb = LocalDatabaseService();

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

    // First check local database cache
    final cachedPdfPath = await _localDb.getCachedPdfPath(widget.filePath);
    if (cachedPdfPath != null && File(cachedPdfPath).existsSync()) {
      setState(() {
        pdfPath = cachedPdfPath;
        isLoading = false;
      });

      // Update question pair with PDF path if needed
      if (widget.questionPairId != null) {
        await _updateQuestionPairWithPdf(cachedPdfPath);
      }

      print('Using cached PDF from local database: $cachedPdfPath');
      return;
    }

    // Check background conversion service cache
    final bgCachedPath =
        _conversionService.getCachedConversion(widget.filePath);
    if (bgCachedPath != null && File(bgCachedPath).existsSync()) {
      setState(() {
        pdfPath = bgCachedPath;
        isLoading = false;
      });

      // Cache it in local database for persistence
      await _localDb.cachePdfConversion(widget.filePath, bgCachedPath);

      // Update question pair with PDF path if needed
      if (widget.questionPairId != null) {
        await _updateQuestionPairWithPdf(bgCachedPath);
      }

      print('Using background service cached PDF: $bgCachedPath');
      return;
    }

    // Check if currently being converted
    if (_conversionService.isConverting(widget.filePath)) {
      _waitForBackgroundConversion();
      return;
    }

    // Check if it's in queue
    if (_conversionService.isInQueue(widget.filePath)) {
      _promoteAndWait();
      return;
    }

    // Not in system yet, convert immediately
    await _convertImmediately();
  }

  Future<void> _updateQuestionPairWithPdf(String pdfPath) async {
    try {
      if (widget.questionPairId == null) return;

      // Determine if this is question or answer based on file path
      final fileName = widget.filePath.toLowerCase();
      final isQuestion =
          fileName.contains('question') || fileName.contains('q_');

      if (isQuestion) {
        await _localDb.updateQuestionPairPdfPaths(
            widget.questionPairId!, pdfPath, null);
      } else {
        await _localDb.updateQuestionPairPdfPaths(
            widget.questionPairId!, null, pdfPath);
      }

      print(
          'Updated question pair ${widget.questionPairId} with PDF path: $pdfPath');
    } catch (e) {
      print('Error updating question pair with PDF path: $e');
    }
  }

  void _waitForBackgroundConversion() {
    setState(() {
      isLoading = true;
    });

    _conversionService.addCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.addProgressListener(
        widget.filePath, _onConversionProgress);
  }

  void _promoteAndWait() {
    setState(() {
      isLoading = true;
    });

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
          // Cache the conversion in local database
          await _localDb.cachePdfConversion(widget.filePath, convertedPath);

          // Update question pair with PDF path if needed
          if (widget.questionPairId != null) {
            await _updateQuestionPairWithPdf(convertedPath);
          }

          setState(() {
            pdfPath = convertedPath;
            isLoading = false;
          });

          print('Immediate conversion completed and cached: $convertedPath');
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
      print('Immediate conversion failed: $e');
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

      // Cache the result in local database if successful
      if (result != null) {
        _localDb.cachePdfConversion(widget.filePath, result);

        // Update question pair with PDF path if needed
        if (widget.questionPairId != null) {
          _updateQuestionPairWithPdf(result);
        }
      }
    }

    _conversionService.removeCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.removeProgressListener(
        widget.filePath, _onConversionProgress);
  }

  void _onConversionProgress(ConversionProgress progress) {
    if (!mounted) return;

    switch (progress) {
      case ConversionProgress.queued:
        break;
      case ConversionProgress.started:
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
        break;
      case ConversionProgress.completed:
        break;
      case ConversionProgress.failed:
        setState(() {
          isLoading = false;
          errorMessage = 'Conversion failed';
        });
        break;
    }
  }

  Future<void> _refreshConversion() async {
    try {
      // Clear cache entries
      await _clearCacheForFile(widget.filePath);

      // Force new conversion
      await _convertImmediately();
    } catch (e) {
      print('Error refreshing conversion: $e');
      setState(() {
        errorMessage = 'Failed to refresh conversion: $e';
      });
    }
  }

  Future<void> _clearCacheForFile(String filePath) async {
    try {
      // This would require additional methods in LocalDatabaseService
      // For now, we'll just re-convert
      print('Clearing cache for: $filePath');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  @override
  void dispose() {
    _conversionService.removeCompletionListener(
        widget.filePath, _onConversionComplete);
    _conversionService.removeProgressListener(
        widget.filePath, _onConversionProgress);

    // Note: We don't clean up the PDF file anymore since it's cached in local DB
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
                  icon: const Icon(Icons.cached),
                  onPressed: _refreshConversion,
                  tooltip: 'Refresh Conversion',
                ),
              ],
              if (!isLoading && pdfPath != null)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showCacheInfo(),
                  tooltip: 'Cache Info',
                ),
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

  void _showCacheInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('PDF Cache Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original File:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.filePath, style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('PDF File:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(pdfPath ?? 'Not available', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Cache Status:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              pdfPath != null ? 'Cached (will not re-convert)' : 'Not cached',
              style: TextStyle(
                fontSize: 12,
                color: pdfPath != null ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (pdfPath != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _refreshConversion();
              },
              child: const Text('Force Re-convert'),
            ),
        ],
      ),
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
            Icons.cached,
            size: 12,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Cached',
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
                  ? 'PDF will be cached for future viewing'
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
                  'Document loaded: ${details.document.pages.count} pages (cached)'),
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
