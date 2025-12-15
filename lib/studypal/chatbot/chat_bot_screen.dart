import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gcr/studypal/chatbot/chat_logic.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:gcr/studypal/theme/animated_background.dart';
import 'package:gcr/studypal/theme/app_theme.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

/// Top-level helper functions for isolate computation (used by compute() for non-blocking operations)
String _computeBase64(List<int> bytesList) =>
    base64Encode(Uint8List.fromList(bytesList));

/// Extracts text content from various document formats (DOCX, TXT, PDF).
/// This function runs in an isolate to avoid blocking the UI thread.
String _extractTextSync(Map args) {
  final List<int> bytesList = List<int>.from(args['bytes'] as List);
  final String name = args['name'] as String;
  final Uint8List bytes = Uint8List.fromList(bytesList);
  final ext = name.split('.').last.toLowerCase();

  try {
    // Extract text from DOCX (Microsoft Word) files by parsing XML from the archive
    if (ext == 'docx') {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.name == 'word/document.xml') {
          final xmlStr = utf8.decode(file.content as List<int>);
          final doc = XmlDocument.parse(xmlStr);
          final texts = doc.findAllElements('t').map((n) => n.text).join(' ');
          return texts;
        }
      }
    } else if (ext == 'txt') {
      // Simply decode text files as UTF-8
      return utf8.decode(bytes);
    } else if (ext == 'pdf') {
      // Extract text from PDF by finding printable ASCII runs (heuristic approach)
      final s = utf8.decode(bytes, allowMalformed: true);
      final regex = RegExp(r'[\x20-\x7E]{30,}');
      final matches = regex
          .allMatches(s)
          .map((m) => m.group(0))
          .where((e) => e != null)
          .cast<String>()
          .toList();
      if (matches.isNotEmpty) {
        return matches.take(5).join('\n\n');
      }
    }
  } catch (e) {
    // Silently handle any extraction errors and return empty string
    debugPrint("Error extracting text: $e");
  }
  return '';
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Instance of ChatLogic for managing AI conversation and note memory
  final ChatLogic _chatLogic = ChatLogic();

  final ImagePicker _picker = ImagePicker();
  // Gemini instance for AI processing (currently used for image and document analysis)
  final Gemini gemini = Gemini.instance;
  bool _isTyping = false;

  // Chat message history - starts with a welcome message from the AI assistant
  final List<Map<String, dynamic>> _messages = [
    {
      "isUser": false,
      "text":
          "Hello! I'm StudyPal AI. 🤖\n\nI can help you from your class notes. Ask me anything!",
      "time": "Now",
    },
  ];

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Handles sending user messages to the AI and receiving responses.
  /// Updates UI to show both user input and AI response.
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user message to chat UI and show loading state
    setState(() {
      _messages.add({
        "isUser": true,
        "text": text,
        "time": DateFormat('hh:mm a').format(DateTime.now()),
      });
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Send message to ChatLogic for processing with AI (checks memory and generates response)
    String responseText = await _chatLogic.getAnswer(text);

    // Update UI with AI response message
    setState(() {
      _messages.add({
        "isUser": false,
        "text": responseText,
        "time": DateFormat('hh:mm a').format(DateTime.now()),
      });
      _isTyping = false;
    });
    _scrollToBottom();
  }

  /// Opens a dialog for adding study notes directly to the AI's memory.
  /// This allows testing the note storage system and retrieval features.
  Future<void> _addTestNoteDialog() async {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController contentCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Class Note"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: "Topic (e.g., Physics)",
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Paste Note Content here...",
                  ),
                ),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (contentCtrl.text.isEmpty) return;

                        setDialogState(
                          () => isSaving = true,
                        ); // Show loading indicator

                        // Save the note to ChatLogic's memory system
                        await _chatLogic.saveNoteToMemory(
                          titleCtrl.text,
                          contentCtrl.text,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Note Saved! AI can now answer questions about this.",
                              ),
                            ),
                          );
                        }
                      },
                child: const Text("Save to Memory"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Processes images selected from gallery or camera.
  /// Sends the image to Gemini AI for analysis and receives study insights.
  Future<void> _processImage(XFile pickedFile) async {
    final Uint8List imageBytes = await pickedFile.readAsBytes();
    final String base64Image = base64Encode(imageBytes);
    final inlineData = InlineData(mimeType: 'image/png', data: base64Image);

    // Store image bytes in message object to prevent re-reading from disk on widget
    // Cache bytes in the message to avoid repeated File I/O on rebuilds
    setState(() {
      _messages.add({
        "isUser": true,
        "text": "",
        "imageBytes": imageBytes,
        "imagePath": pickedFile.path,
        "time": DateFormat('hh:mm a').format(DateTime.now()),
      });
      _isTyping = true;
    });
    _scrollToBottom();

    gemini
        .promptStream(
          parts: [
            Part.text("Analyze this image as a study helper."),
            Part.inline(inlineData),
          ],
        )
        .listen((event) {
          final reply = event?.output ?? "";
          setState(() {
            if (_messages.isNotEmpty && _messages.last["isUser"] == false) {
              _messages.last["text"] = (_messages.last["text"] ?? "") + reply;
            } else {
              _messages.add({
                "isUser": false,
                "text": reply,
                "time": DateFormat('hh:mm a').format(DateTime.now()),
              });
            }
            _isTyping = false;
            _scrollToBottom();
          });
        });
  }

  /// Handles processing of document files (PDF, DOCX, TXT, PPT, etc.).
  /// Extracts text locally first, then sends to AI for analysis.
  /// Saves extracted content to memory for future reference.
  // --- FILE HANDLING (pdf/docx/txt/ppt etc) ---
  Future<void> _processPlatformFile(PlatformFile file) async {
    try {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      // Extract text locally in an isolate to avoid blocking the main UI thread
      if (bytes == null) return;

      // Try local extraction first (run in isolate)
      final extracted = await compute(_extractTextSync, {
        'bytes': bytes.toList(),
        'name': file.name,
      });

      setState(() {
        _messages.add({
          "isUser": true,
          "text": "",
          "fileName": file.name,
          "time": DateFormat('hh:mm a').format(DateTime.now()),
        });
        _isTyping = true;
      });

      if (extracted.isNotEmpty) {
        // Save locally-extracted text to memory immediately (RAG)
        try {
          await _chatLogic.saveNoteToMemory(file.name, extracted);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved "${file.name}" to memory.')),
            );
          }
        } catch (e) {
          debugPrint('Error saving extracted note: $e');
        }

        // Send extracted text to Gemini (smaller payload)
        final promptText =
            "Analyze this extracted document as a study helper and extract concise notes. File: ${file.name}\n\n$extracted";
        final buffer = StringBuffer();
        gemini
            .promptStream(parts: [Part.text(promptText)])
            .listen(
              (event) {
                final reply = event?.output ?? "";
                buffer.write(reply);
                setState(() {
                  if (_messages.isNotEmpty &&
                      _messages.last["isUser"] == false) {
                    _messages.last["text"] =
                        (_messages.last["text"] ?? "") + reply;
                  } else {
                    _messages.add({
                      "isUser": false,
                      "text": reply,
                      "time": DateFormat('hh:mm a').format(DateTime.now()),
                    });
                  }
                  _isTyping = false;
                  _scrollToBottom();
                });
              },
              onError: (e) {
                setState(() {
                  _messages.add({
                    "isUser": false,
                    "text": "Error analyzing document.",
                    "time": DateFormat('hh:mm a').format(DateTime.now()),
                  });
                  _isTyping = false;
                });
              },
              onDone: () async {
                // Finalize anything if needed
              },
            );
      } else {
        // Fallback: send raw bytes as inline, but encode in an isolate to avoid blocking UI
        final base64Data = await compute(_computeBase64, bytes.toList());
        final mimeType =
            lookupMimeType(file.name, headerBytes: bytes) ??
            'application/octet-stream';
        final inlineData = InlineData(mimeType: mimeType, data: base64Data);

        final promptText =
            "Analyze this document as a study helper and extract concise notes. File: ${file.name}";
        final buffer = StringBuffer();
        gemini
            .promptStream(
              parts: [Part.text(promptText), Part.inline(inlineData)],
            )
            .listen(
              (event) {
                final reply = event?.output ?? "";
                buffer.write(reply);
                setState(() {
                  if (_messages.isNotEmpty &&
                      _messages.last["isUser"] == false) {
                    _messages.last["text"] =
                        (_messages.last["text"] ?? "") + reply;
                  } else {
                    _messages.add({
                      "isUser": false,
                      "text": reply,
                      "time": DateFormat('hh:mm a').format(DateTime.now()),
                    });
                  }
                  _isTyping = false;
                  _scrollToBottom();
                });
              },
              onError: (e) {
                setState(() {
                  _messages.add({
                    "isUser": false,
                    "text": "Error analyzing document.",
                    "time": DateFormat('hh:mm a').format(DateTime.now()),
                  });
                  _isTyping = false;
                });
              },
              onDone: () async {
                final extracted2 = buffer.toString().trim();
                if (extracted2.isNotEmpty) {
                  try {
                    await _chatLogic.saveNoteToMemory(file.name, extracted2);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved "${file.name}" to memory.'),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error saving extracted note: $e');
                  }
                }
              },
            );
      }
    } catch (e) {
      debugPrint('Error processing file: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        await _processPlatformFile(result.files.first);
      }
    } catch (e) {
      debugPrint('File pick error: $e');
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: Text("Gallery", style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _picker.pickImage(source: ImageSource.gallery).then((f) {
                    if (f != null) _processImage(f);
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: AppColors.primary,
                ),
                title: Text("Files", style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text("Camera", style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _picker.pickImage(source: ImageSource.camera).then((f) {
                    if (f != null) _processImage(f);
                  });
                },
              ),
              // Option to manually add notes for AI training and testing
              ListTile(
                leading: const Icon(Icons.note_add, color: Colors.orange),
                title: Text(
                  "Add Note (Train AI)",
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addTestNoteDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      colors: AppTheme.accentGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "StudyPal Assistant",
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isTyping ? Colors.blue : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        _isTyping ? "Thinking..." : "Online",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black54),
              onPressed: _addTestNoteDialog, // Header main bhi shortcut de diya
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['isUser'];
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      constraints: BoxConstraints(maxWidth: 0.75.sw),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.r),
                          topRight: Radius.circular(16.r),
                          bottomLeft: isUser
                              ? Radius.circular(16.r)
                              : Radius.zero,
                          bottomRight: isUser
                              ? Radius.zero
                              : Radius.circular(16.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg['imageBytes'] != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.memory(
                                  msg['imageBytes'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else if (msg['imagePath'] != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.file(File(msg['imagePath'])),
                              ),
                            )
                          else if (msg['fileName'] != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 28),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      msg['fileName'],
                                      style: GoogleFonts.poppins(
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14.sp,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if ((msg['text'] ?? "").isNotEmpty)
                            GptMarkdown(
                              msg['text'],
                              style: GoogleFonts.poppins(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 14.sp,
                                height: 1.4,
                              ),
                            ),
                          SizedBox(height: 4.h),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              msg['time'] ?? "",
                              style: GoogleFonts.poppins(
                                color: isUser
                                    ? Colors.white70
                                    : Colors.grey[400],
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        10.h,
        16.w,
        isKeyboardOpen ? 20.h : 100.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _showAttachmentOptions,
            child: Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: Icon(
                Icons.attach_file,
                color: Colors.grey[400],
                size: 24.sp,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.poppins(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: "Ask StudyPal...",
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _isTyping
                  ? SizedBox(
                      width: 20.sp,
                      height: 20.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }
}
