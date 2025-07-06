import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class DocumentConverterService {
  static const String _tempDirName = 'temp_pdf_previews';

  /// Convert a document file to PDF for preview
  /// Returns the path to the converted PDF file
  static Future<String?> convertToPdf(String originalFilePath) async {
    try {
      final file = File(originalFilePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist: $originalFilePath');
      }

      final extension = path.extension(originalFilePath).toLowerCase();

      switch (extension) {
        case '.pdf':
          // Already a PDF, return original path
          return originalFilePath;
        case '.doc':
        case '.docx':
        case '.gnm':
          // Use Microsoft Office or LibreOffice with better settings
          return await _convertDocToPdfAdvanced(originalFilePath);
        case '.txt':
          return await _convertTextToPdf(originalFilePath);
        default:
          debugPrint('Unsupported file type for conversion: $extension');
          return null;
      }
    } catch (e) {
      debugPrint('Error converting file to PDF: $e');
      return null;
    }
  }

  /// Convert DOC/DOCX/GNM files to PDF with advanced settings to preserve images and expressions
  static Future<String?> _convertDocToPdfAdvanced(String filePath) async {
    try {
      final tempDir = await _getTempDirectory();
      final fileName = path.basenameWithoutExtension(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(filePath).toLowerCase();
      final outputPath = path.join(tempDir.path, '${fileName}_$timestamp.pdf');

      debugPrint(
          'Converting ${extension.toUpperCase()} document to PDF with advanced settings: $filePath');

      // Try multiple conversion methods in order of preference
      bool conversionSuccess = false;

      // Method 1: Try Microsoft Office if available (Windows)
      if (Platform.isWindows && !conversionSuccess) {
        conversionSuccess =
            await _tryMicrosoftOfficeToPdf(filePath, outputPath);
      }

      // Method 2: Try LibreOffice with advanced parameters
      if (!conversionSuccess) {
        conversionSuccess =
            await _tryLibreOfficeAdvancedToPdf(filePath, outputPath);
      }

      // Method 3: Try PowerShell with Word automation (Windows)
      if (Platform.isWindows && !conversionSuccess) {
        conversionSuccess = await _tryPowerShellWordToPdf(filePath, outputPath);
      }

      // Method 4: Try using pandoc if available
      if (!conversionSuccess) {
        conversionSuccess = await _tryPandocToPdf(filePath, outputPath);
      }

      if (conversionSuccess && File(outputPath).existsSync()) {
        debugPrint(
            '${extension.toUpperCase()} document converted successfully: $outputPath');
        return outputPath;
      } else {
        debugPrint('All conversion methods failed, creating informational PDF');
        return await _createInformationalPdf(filePath);
      }
    } catch (e) {
      final extension = path.extension(filePath).toLowerCase();
      debugPrint('Error converting ${extension.toUpperCase()} to PDF: $e');
      return await _createInformationalPdf(filePath);
    }
  }

  /// Try Microsoft Office conversion (Windows only)
  static Future<bool> _tryMicrosoftOfficeToPdf(
      String inputPath, String outputPath) async {
    try {
      debugPrint('Attempting Microsoft Office conversion...');

      // Try using Word automation via VBScript
      final vbsScript = '''
Dim objWord
Dim objDoc
Set objWord = CreateObject("Word.Application")
objWord.Visible = False
objWord.DisplayAlerts = False
Set objDoc = objWord.Documents.Open("$inputPath")
objDoc.ExportAsFixedFormat "$outputPath", 17, False, 0, 0, 0, 0, 7, True, True, 2, True, True, False
objDoc.Close False
objWord.Quit False
Set objDoc = Nothing
Set objWord = Nothing
      ''';

      final tempDir = await _getTempDirectory();
      final vbsPath = path.join(
          tempDir.path, 'convert_${DateTime.now().millisecondsSinceEpoch}.vbs');
      await File(vbsPath).writeAsString(vbsScript);

      final result = await Process.run(
        'cscript',
        ['/nologo', vbsPath],
        runInShell: true,
      );

      // Clean up VBS file
      try {
        await File(vbsPath).delete();
      } catch (e) {
        debugPrint('Could not delete VBS file: $e');
      }

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        debugPrint('Microsoft Office conversion successful');
        return true;
      }
    } catch (e) {
      debugPrint('Microsoft Office conversion failed: $e');
    }
    return false;
  }

  /// Try LibreOffice with advanced parameters to preserve images and formatting
  static Future<bool> _tryLibreOfficeAdvancedToPdf(
      String inputPath, String outputPath) async {
    try {
      debugPrint('Attempting LibreOffice advanced conversion...');

      final tempDir = await _getTempDirectory();
      final outputDir = tempDir.path;

      // LibreOffice command with advanced parameters
      final libreOfficeCommands = _getLibreOfficeCommands();

      for (final command in libreOfficeCommands) {
        try {
          final result = await Process.run(
            command,
            [
              '--headless',
              '--convert-to',
              'pdf:writer_pdf_Export:{"Quality":100,"ReduceImageResolution":false,"MaxImageResolution":300,"UseTaggedPDF":true}',
              '--outdir',
              outputDir,
              inputPath,
            ],
            runInShell: Platform.isWindows,
          );

          if (result.exitCode == 0) {
            // LibreOffice creates PDF with same base name
            final expectedPdfPath = path.join(
                outputDir, '${path.basenameWithoutExtension(inputPath)}.pdf');
            final pdfFile = File(expectedPdfPath);

            if (pdfFile.existsSync()) {
              await pdfFile.rename(outputPath);
              debugPrint('LibreOffice advanced conversion successful');
              return true;
            }
          }
        } catch (e) {
          debugPrint('LibreOffice command $command failed: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('LibreOffice advanced conversion failed: $e');
    }
    return false;
  }

  /// Try PowerShell with Word automation (Windows)
  static Future<bool> _tryPowerShellWordToPdf(
      String inputPath, String outputPath) async {
    try {
      debugPrint('Attempting PowerShell Word automation...');

      final psScript = '''
\$word = New-Object -ComObject Word.Application
\$word.Visible = \$false
\$word.DisplayAlerts = 'wdAlertsNone'
\$doc = \$word.Documents.Open('$inputPath')
\$doc.ExportAsFixedFormat('$outputPath', 'wdExportFormatPDF', \$false, 'wdExportOptimizeForMaximumQuality', 'wdExportRangeAllDocument', 1, 1, 'wdExportWithoutMarkup', \$true, \$true, 'wdExportCreateBookmarks', \$true, \$true, \$false)
\$doc.Close(\$false)
\$word.Quit(\$false)
[System.Runtime.Interopservices.Marshal]::ReleaseComObject(\$word) | Out-Null
      ''';

      final result = await Process.run(
        'powershell',
        ['-Command', psScript],
        runInShell: true,
      );

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        debugPrint('PowerShell Word automation successful');
        return true;
      }
    } catch (e) {
      debugPrint('PowerShell Word automation failed: $e');
    }
    return false;
  }

  /// Try Pandoc conversion
  static Future<bool> _tryPandocToPdf(
      String inputPath, String outputPath) async {
    try {
      debugPrint('Attempting Pandoc conversion...');

      final result = await Process.run(
        'pandoc',
        [
          inputPath,
          '-o',
          outputPath,
          '--pdf-engine=xelatex',
          '--extract-media=.',
        ],
        runInShell: true,
      );

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        debugPrint('Pandoc conversion successful');
        return true;
      }
    } catch (e) {
      debugPrint('Pandoc conversion failed: $e');
    }
    return false;
  }

  /// Get LibreOffice command paths for different platforms
  static List<String> _getLibreOfficeCommands() {
    if (Platform.isWindows) {
      return [
        'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
        'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
        'soffice',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/Applications/LibreOffice.app/Contents/MacOS/soffice',
        'soffice',
        'libreoffice',
      ];
    } else {
      return [
        'libreoffice',
        'soffice',
      ];
    }
  }

  /// Convert text files to PDF
  static Future<String?> _convertTextToPdf(String filePath) async {
    try {
      final tempDir = await _getTempDirectory();
      final fileName = path.basenameWithoutExtension(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(tempDir.path, '${fileName}_$timestamp.pdf');

      final content = await File(filePath).readAsString();

      // Create HTML file first
      final htmlPath = path.join(tempDir.path, '${fileName}_$timestamp.html');
      final htmlContent = _createHtmlFromText(content, path.basename(filePath));
      await File(htmlPath).writeAsString(htmlContent);

      // Try to convert HTML to PDF
      final success = await _convertHtmlToPdf(htmlPath, outputPath);

      // Clean up HTML file
      try {
        await File(htmlPath).delete();
      } catch (e) {
        debugPrint('Could not delete temp HTML file: $e');
      }

      return success ? outputPath : null;
    } catch (e) {
      debugPrint('Error converting text to PDF: $e');
      return null;
    }
  }

  /// Create an informational PDF when conversion fails
  static Future<String?> _createInformationalPdf(String originalPath) async {
    try {
      final tempDir = await _getTempDirectory();
      final fileName = path.basenameWithoutExtension(originalPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath =
          path.join(tempDir.path, '${fileName}_info_$timestamp.pdf');

      final file = File(originalPath);
      final extension = path.extension(originalPath).toLowerCase();
      final fileSize = await file.length();
      final lastModified = await file.lastModified();

      final content = '''
📄 Document Preview Unavailable
================================

Unfortunately, this document cannot be converted to PDF while preserving 
images, mathematical expressions, and complex formatting.

📋 File Information:
• Name: ${path.basename(originalPath)}
• Type: ${extension.toUpperCase()} Document
• Size: ${_formatFileSize(fileSize)}
• Modified: ${_formatDateTime(lastModified)}

⚠️ Why Preview Failed:
• Document contains complex formatting (images, equations, special layouts)
• Conversion tools cannot preserve all visual elements
• Mathematical expressions and embedded objects need native application

💡 Recommended Actions:
1. Click "Open in External App" to view the complete document
2. Use Microsoft Word, LibreOffice, or appropriate application
3. Verify content in the original application before uploading

🔍 What You Can Still Do:
• Upload the file - all content will be preserved in the original format
• Preview will work better with simpler documents or PDFs
• The actual uploaded file retains all formatting and images

This preview limitation does not affect the file upload or storage.
Your original document with all formatting will be saved correctly.
      ''';

      // Create HTML and convert to PDF
      final htmlPath =
          path.join(tempDir.path, '${fileName}_info_$timestamp.html');
      final htmlContent =
          _createHtmlFromText(content, path.basename(originalPath));
      await File(htmlPath).writeAsString(htmlContent);

      final success = await _convertHtmlToPdf(htmlPath, outputPath);

      // Clean up HTML file
      try {
        await File(htmlPath).delete();
      } catch (e) {
        debugPrint('Could not delete temp HTML file: $e');
      }

      return success ? outputPath : null;
    } catch (e) {
      debugPrint('Error creating informational PDF: $e');
      return null;
    }
  }

  /// Create HTML content from text
  static String _createHtmlFromText(String content, String fileName) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 30px; 
            line-height: 1.8;
            background-color: white;
            color: #333;
        }
        .header { 
            border-bottom: 3px solid #007acc; 
            padding-bottom: 15px; 
            margin-bottom: 30px; 
        }
        .header h1 {
            margin: 0;
            color: #007acc;
            font-size: 22px;
        }
        .filename {
            color: #666;
            font-style: italic;
            margin-top: 8px;
            font-size: 14px;
        }
        .content { 
            white-space: pre-wrap; 
            word-wrap: break-word;
            font-size: 13px;
            line-height: 1.6;
            background-color: #fafafa;
            padding: 20px;
            border-left: 4px solid #007acc;
            border-radius: 4px;
        }
        .emoji {
            font-size: 16px;
            margin-right: 8px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📄 Document Preview</h1>
        <div class="filename">File: $fileName</div>
    </div>
    <div class="content">${_escapeHtml(content)}</div>
</body>
</html>
    ''';
  }

  /// Convert HTML to PDF using Chrome/Chromium headless
  static Future<bool> _convertHtmlToPdf(
      String htmlPath, String outputPath) async {
    try {
      final chromePaths = _getChromePaths();

      for (final chromePath in chromePaths) {
        try {
          final result = await Process.run(
            chromePath,
            [
              '--headless',
              '--disable-gpu',
              '--disable-software-rasterizer',
              '--disable-dev-shm-usage',
              '--no-sandbox',
              '--print-to-pdf=$outputPath',
              '--print-to-pdf-no-header',
              '--virtual-time-budget=2000',
              htmlPath,
            ],
            runInShell: Platform.isWindows,
          );

          if (result.exitCode == 0 && File(outputPath).existsSync()) {
            debugPrint('PDF created successfully using $chromePath');
            return true;
          }
        } catch (e) {
          debugPrint('Failed to use $chromePath: $e');
          continue;
        }
      }

      debugPrint('Could not create PDF: No suitable browser found');
      return false;
    } catch (e) {
      debugPrint('Error converting HTML to PDF: $e');
      return false;
    }
  }

  /// Get possible Chrome/Chromium paths for different platforms
  static List<String> _getChromePaths() {
    if (Platform.isWindows) {
      return [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        'chrome',
        'google-chrome',
      ];
    } else if (Platform.isMacOS) {
      return [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        'google-chrome',
        'chromium',
      ];
    } else {
      return [
        'google-chrome',
        'google-chrome-stable',
        'chromium-browser',
        'chromium',
      ];
    }
  }

  /// Get or create temporary directory for PDF files
  static Future<Directory> _getTempDirectory() async {
    final tempDir = Directory.systemTemp;
    final pdfTempDir = Directory(path.join(tempDir.path, _tempDirName));

    if (!await pdfTempDir.exists()) {
      await pdfTempDir.create(recursive: true);
    }

    return pdfTempDir;
  }

  /// Clean up temporary PDF files
  static Future<void> cleanupTempPdfs([List<String>? specificFiles]) async {
    try {
      final tempDir =
          Directory(path.join(Directory.systemTemp.path, _tempDirName));

      if (!await tempDir.exists()) return;

      if (specificFiles != null) {
        for (final filePath in specificFiles) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
              debugPrint('Cleaned up temp PDF: $filePath');
            }
          } catch (e) {
            debugPrint('Error deleting temp PDF: $filePath, $e');
          }
        }
      } else {
        final now = DateTime.now();
        await for (final entity in tempDir.list()) {
          if (entity is File) {
            try {
              final stat = await entity.stat();
              final age = now.difference(stat.modified);
              if (age.inHours >= 2) {
                await entity.delete();
                debugPrint('Cleaned up old temp file: ${entity.path}');
              }
            } catch (e) {
              debugPrint('Error cleaning up temp file: ${entity.path}, $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp PDFs: $e');
    }
  }

  /// Format file size in human readable format
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format DateTime in readable format
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Escape HTML special characters
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Check if conversion tools are available
  static Future<Map<String, bool>> checkAvailableTools() async {
    final tools = <String, bool>{};

    // Check Microsoft Office (Windows only)
    if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell',
            ['-Command', 'Get-Process WINWORD -ErrorAction SilentlyContinue']);
        tools['Microsoft Word'] = true;
      } catch (e) {
        tools['Microsoft Word'] = false;
      }
    }

    // Check LibreOffice
    try {
      final commands = _getLibreOfficeCommands();
      bool libreOfficeFound = false;
      for (final command in commands) {
        try {
          final result = await Process.run(command, ['--version'],
              runInShell: Platform.isWindows);
          if (result.exitCode == 0) {
            libreOfficeFound = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }
      tools['LibreOffice'] = libreOfficeFound;
    } catch (e) {
      tools['LibreOffice'] = false;
    }

    return tools;
  }
}
