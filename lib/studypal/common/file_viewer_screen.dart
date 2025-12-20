import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'dart:convert';

class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const FileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isImage = false;

  @override
  void initState() {
    super.initState();

    // 1. Check if it is an image
    if (widget.fileName.toLowerCase().endsWith('.jpg') ||
        widget.fileName.toLowerCase().endsWith('.png') ||
        widget.fileName.toLowerCase().endsWith('.jpeg')) {
      _isImage = true;
      _isLoading = false;
    } else {
      // 2. If it is a Doc/PDF, setup the WebView with Google Docs Viewer
      // Google's Viewer URL: https://docs.google.com/gview?embedded=true&url=YOUR_FILE_URL
      final String googleDocsUrl =
          "https://docs.google.com/gview?embedded=true&url=${widget.fileUrl}";

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(googleDocsUrl));
    }
  }

  String _getDocumentType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.pdf')) return 'PDF document';
    if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
      return 'Word document';
    }
    if (lowerName.endsWith('.ppt') || lowerName.endsWith('.pptx')) {
      return 'PowerPoint presentation';
    }
    if (lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx')) {
      return 'Excel spreadsheet';
    }
    if (lowerName.endsWith('.txt')) return 'text file';
    if (lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png')) {
      return 'image file';
    }
    return 'document';
  }

  // Background task for PDF extraction (runs in separate isolate)
  static Future<String> _extractPdfTextInBackground(Uint8List pdfBytes) async {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    String text = PdfTextExtractor(document).extractText();
    document.dispose();

    // Limit text to reasonable size
    if (text.length > 3000) {
      text =
          '${text.substring(0, 3000)}\n\n[Document truncated for analysis...]';
    }
    return text;
  }

  // Background task for DOCX extraction (runs in separate isolate)
  static Future<String> _extractDocxTextInBackground(
    Uint8List docxBytes,
  ) async {
    try {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final documentXml = archive.findFile('word/document.xml');

      if (documentXml != null) {
        final xmlString = utf8.decode(documentXml.content as List<int>);
        // Extract text between XML tags
        final textPattern = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
        final matches = textPattern.allMatches(xmlString);
        String text = matches.map((m) => m.group(1) ?? '').join(' ');
        // Clean up extra spaces
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Limit text to reasonable size
        if (text.length > 3000) {
          text =
              '${text.substring(0, 3000)}\n\n[Document truncated for analysis...]';
        }
        return text.isNotEmpty ? text : 'Unable to extract text from document';
      }
      return 'Unable to extract text from document';
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }

  Future<String?> _extractTextFromDocument() async {
    try {
      final lowerName = widget.fileName.toLowerCase();

      // For PDFs, extract text in background
      if (lowerName.endsWith('.pdf')) {
        final response = await http
            .get(Uri.parse(widget.fileUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          // Run PDF extraction in background isolate to avoid blocking UI
          final text = await Isolate.run(
            () => _extractPdfTextInBackground(response.bodyBytes),
          );
          return text;
        }
      }

      // For Word documents (.docx), extract text in background
      if (lowerName.endsWith('.docx')) {
        final response = await http
            .get(Uri.parse(widget.fileUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          // Run DOCX extraction in background isolate
          final text = await Isolate.run(
            () => _extractDocxTextInBackground(response.bodyBytes),
          );
          return text;
        }
      }

      // For images, return URL for image analysis
      if (lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png')) {
        return 'IMAGE_URL:${widget.fileUrl}';
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting text: $e');
      return null;
    }
  }

  void _analyzeDocument() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Extracting document content...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final extractedText = await _extractTextFromDocument();

    // Debug logging
    debugPrint('📄 Extracted text length: ${extractedText?.length ?? 0}');
    debugPrint(
      '📄 Extracted text preview: ${extractedText?.substring(0, extractedText.length > 100 ? 100 : extractedText.length) ?? "null"}',
    );

    // Close loading dialog
    if (mounted) Navigator.pop(context);

    String prompt;
    if (extractedText != null && extractedText.startsWith('IMAGE_URL:')) {
      // For images, guide user to use image upload feature
      prompt =
          'I have an image document "${widget.fileName}". Please use the 📷 camera icon below to analyze this image, or I can describe what\'s in the document. How would you like me to proceed?';
    } else if (extractedText != null &&
        extractedText.isNotEmpty &&
        !extractedText.contains('Unable to extract') &&
        !extractedText.contains('Error extracting')) {
      // For documents with successfully extracted text
      prompt =
          'I have extracted the text from "${widget.fileName}". Here is the content:\n\n---\n$extractedText\n---\n\nPlease provide:\n1. Comprehensive summary\n2. Key points and main topics\n3. Important details and insights\n4. Actionable takeaways';
    } else {
      // Fallback for extraction failures or other document types
      final errorInfo = extractedText != null && extractedText.contains('Error')
          ? '\n\n⚠️ Extraction failed: $extractedText'
          : '';
      prompt =
          'I\'m viewing a ${_getDocumentType(widget.fileName)} called "${widget.fileName}".$errorInfo\n\nTo help me analyze it, you can:\n1. Use the 📷 icon to upload screenshots\n2. Or I can paste the text content\n\nOnce you have the content, provide:\n✓ Summary\n✓ Key points\n✓ Important details\n✓ Insights\n\nHow should I share the content?';
    }

    if (mounted) {
      // Navigate back to close the file viewer
      Navigator.pop(context);

      // Navigate back to home and switch to chatbot tab
      // Pass the extracted text as result
      Navigator.pop(context, {'navigateToChatbot': true, 'message': prompt});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _analyzeDocument,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          'Analyze with AI',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          // CONTENT
          _isImage
              ? Center(
                  child: InteractiveViewer(
                    // Allows zooming in/out of images
                    child: CachedNetworkImage(
                      imageUrl: widget.fileUrl,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 250),
                      placeholder: (context, url) => const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : WebViewWidget(controller: _controller),

          // LOADING SPINNER
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
