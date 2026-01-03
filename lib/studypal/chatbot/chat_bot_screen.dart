import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'chat_logic.dart';
import 'package:provider/provider.dart';
import 'chat_bot_provider.dart';
import '../models/subject_model.dart';

class ChatBotScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? documentUrl;
  final String? documentName;
  final SubjectModel? subject;

  const ChatBotScreen({
    super.key,
    this.initialPrompt,
    this.documentUrl,
    this.documentName,
    this.subject,
  });

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatLogic _chatLogic = ChatLogic();
  final ImagePicker _picker = ImagePicker();
  // ignore: unused_field
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _isTyping = false;
  bool _isInitializing = true;
  final List<Map<String, dynamic>> _messages = [];
  late AnimationController _typingAnimationController;
  StreamSubscription<String>? _imageStreamSub;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _controller.addListener(() {
      setState(() {});
    });
    _initializeRAG();

    // Process initial prompt if provided
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _controller.text = widget.initialPrompt!;
          sendMessage();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _imageStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeRAG() async {
    try {
      await _chatLogic.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('❌ RAG initialization failed: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  // UPDATED: Now seeds "StudyPal" identity data instead of personal data
  Future<void> _seedInitialData() async {
    setState(() => _isTyping = true);

    try {
      // Identity & Purpose
      await _chatLogic.learnFact(
        "I am StudyPal, an intelligent AI study assistant designed to help students learn faster and more efficiently.",
      );

      // Capabilities
      await _chatLogic.learnFact(
        "I can explain complex concepts, solve problems, and analyze images of notes or diagrams.",
      );

      // Domain Knowledge (General CS Context)
      await _chatLogic.learnFact(
        "I specialize in Computer Science topics like Algorithms, Data Structures, Operating Systems, and Linear Algebra.",
      );

      // Feature Awareness
      await _chatLogic.learnFact(
        "I use RAG (Retrieval-Augmented Generation) to search your uploaded notes and provide accurate, context-aware answers.",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ StudyPal core knowledge loaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to seed data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        "isUser": true,
        "text": text,
        "time": DateFormat('h:mm a').format(DateTime.now()),
      });
      _controller.clear();
    });
    scrollToBottom();
    // Save message using provider (no reload)
    await Provider.of<ChatBotProvider>(
      context,
      listen: false,
    ).addMessage(text, subject: widget.subject);

    // ...existing logic for custom commands and LLM...
    // ----------------------------------------------------

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _isTyping = true);

    try {
      final detailResponse = await _chatLogic.captureUserDetail(text);
      if (detailResponse != null) {
        if (mounted) {
          setState(() {
            _messages.add({
              "isUser": false,
              "text": detailResponse,
              "time": DateFormat('h:mm a').format(DateTime.now()),
            });
            _isTyping = false;
          });
        }
        scrollToBottom();
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "isUser": false,
            "text": "I couldn't save that detail: $e",
            "time": DateFormat('h:mm a').format(DateTime.now()),
          });
          _isTyping = false;
        });
      }
      scrollToBottom();
      return;
    }

    try {
      final reply = await _chatLogic.getAnswerWithRAG(text);
      if (mounted) {
        setState(() {
          _messages.add({
            "isUser": false,
            "text": reply,
            "time": DateFormat('h:mm a').format(DateTime.now()),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "isUser": false,
            "text": "Sorry, something went wrong while fetching the answer.",
            "time": DateFormat('h:mm a').format(DateTime.now()),
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
      scrollToBottom();
    }
  }

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();

    setState(() {
      _messages.add({
        "isUser": true,
        "text": "📷 Sent an image",
        "time": DateFormat('h:mm a').format(DateTime.now()),
        "isImage": true,
      });
    });
    scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        _messages.add({
          "isUser": false,
          "text": "Analyzing...",
          "time": DateFormat('h:mm a').format(DateTime.now()),
        });
        _isTyping = true;
      });
    }

    String fullResponse = "";
    try {
      await _imageStreamSub?.cancel();
      _imageStreamSub = _chatLogic
          .analyzeImageStream("Explain this image for a student.", bytes)
          .listen(
            (chunk) {
              fullResponse += chunk;
              if (mounted && _messages.isNotEmpty) {
                setState(() {
                  _messages.last['text'] = fullResponse;
                });
              }
            },
            onError: (e, _) {
              if (mounted && _messages.isNotEmpty) {
                setState(() {
                  _messages.last['text'] =
                      "Sorry, something went wrong while analyzing the image.";
                  _isTyping = false;
                });
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Image analysis error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              scrollToBottom();
            },
            onDone: () {
              if (mounted) {
                setState(() => _isTyping = false);
                scrollToBottom();
              }
            },
            cancelOnError: true,
          );
    } catch (e) {
      if (mounted && _messages.isNotEmpty) {
        setState(() {
          _messages.last['text'] =
              "Sorry, something went wrong while starting the analysis.";
          _isTyping = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image analysis setup failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE0F7FA).withValues(alpha: 0.3),
              AppColors.primary.withValues(alpha: 0.05),
              const Color(0xFFF3E5F5).withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isInitializing
                  ? buildInitializingState()
                  : _messages.isEmpty
                  ? buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 20.h,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _buildMessageRowAnimated(_messages[index], index),
                    ),
            ),
            if (_isTyping) buildTypingIndicator(),
            buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,

      title: Column(
        children: [
          Text(
            "StudyPal AI",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.w,
                height: 8.h,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                "RAG Enabled • Online",
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white, size: 24.sp),
          onSelected: (value) async {
            switch (value) {
              case 'clear':
                setState(() => _messages.clear());
                break;
              case 'seed':
                await _seedInitialData();
                break;
              case 'reload':
                setState(() => _isInitializing = true);
                await _initializeRAG();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 20.sp),
                  SizedBox(width: 8.w),
                  const Text('Clear Chat'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'seed',
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, size: 20.sp),
                  SizedBox(width: 8.w),
                  const Text('Seed Identity'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reload',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20.sp),
                  SizedBox(width: 8.w),
                  const Text('Reload Notes'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget buildInitializingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60.w,
            height: 60.w,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "Initializing RAG System...",
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Loading your notes from Firebase",
            style: GoogleFonts.poppins(fontSize: 13.sp, color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Hero(
              tag: 'studypal_bot',
              child: Container(
                padding: EdgeInsets.all(28.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  size: 72.sp,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          SizedBox(height: 28.h),
          Text(
            "Hi, I'm StudyPal!",
            style: GoogleFonts.poppins(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "I can search your notes or analyze\nimages to help you study better.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.grey,
              fontSize: 15.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildAnimatedSuggestionChip("📚 Explain a topic", 0),
              _buildAnimatedSuggestionChip("🔍 Search my notes", 1),
              _buildAnimatedSuggestionChip("🖼️ Analyze image", 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRowAnimated(Map<String, dynamic> msg, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: buildMessageRow(msg),
    );
  }

  Widget buildMessageRow(Map<String, dynamic> msg) {
    final isUser = msg['isUser'];
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                size: 18.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.85),
                        ],
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                  bottomLeft: isUser
                      ? Radius.circular(20.r)
                      : Radius.circular(4.r),
                  bottomRight: isUser
                      ? Radius.circular(4.r)
                      : Radius.circular(20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GptMarkdown(
                    msg['text'] ?? "",
                    style: GoogleFonts.poppins(
                      color: isUser ? Colors.white : AppColors.onSurface,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    msg['time'] ?? "",
                    style: GoogleFonts.poppins(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.grey,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 8.w),
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.person, size: 18.sp, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildTypingIndicator() {
    return AnimatedOpacity(
      opacity: _isTyping ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Padding(
        padding: EdgeInsets.only(left: 50.w, bottom: 12.h),
        child: Row(
          children: [
            _buildPulsingDots(),
            SizedBox(width: 12.w),
            Text(
              "StudyPal is thinking...",
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingDots() {
    return Row(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(right: 4.w),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(_isTyping),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + (index * 100)),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              // Clamp opacity value to ensure it's within valid range
              final opacityValue = (0.5 + (value * 0.5)).clamp(0.0, 1.0);
              return Transform.scale(
                scale: 0.7 + (value * 0.3),
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: opacityValue),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
            onEnd: () {
              if (_isTyping && mounted) {
                setState(() {}); // Restart animation
              }
            },
          ),
        );
      }),
    );
  }

  Widget buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppColors.primary,
                  size: 24.sp,
                ),
                onPressed: pickImage,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(25.r),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.poppins(
                    color: AppColors.onSurface,
                    fontSize: 14.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: "Ask me anything...",
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.grey,
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  onSubmitted: (_) {
                    sendMessage();
                  },
                ),
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedScale(
              scale: _controller.text.isEmpty ? 0.9 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                  onPressed: () {
                    sendMessage();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSuggestionChip(String text, int index) {
    return buildSuggestionChip(text);
  }

  Widget buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: AppColors.primary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
