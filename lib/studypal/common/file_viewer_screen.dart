import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:gcr/studypal/theme/animated_background.dart';
import 'package:gcr/studypal/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      colors: AppTheme.primaryGradient,
      child: Scaffold(
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
        body: Stack(
          children: [
            // CONTENT
            _isImage
                ? Center(
                    child: InteractiveViewer(
                      // Allows zooming in/out of images
                      child: Image.network(widget.fileUrl),
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
      ),
    );
  }
}
