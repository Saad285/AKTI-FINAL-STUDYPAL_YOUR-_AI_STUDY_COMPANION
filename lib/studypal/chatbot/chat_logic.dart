import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'gemini_bootstrap.dart';
import 'vector_store.dart';

class ChatLogic {
  late final Gemini gemini;
  late final VectorStore vectorStore;
  bool _isInitialized = false;

  ChatLogic() {
    GeminiBootstrap.ensureInitialized();
    gemini = Gemini.instance;
    vectorStore = VectorStore();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await vectorStore.fetchNotes();
      _isInitialized = true;
      debugPrint('✅ RAG System initialized successfully');
    } catch (e) {
      debugPrint('❌ RAG initialization error: $e');
      rethrow;
    }
  }

  // --- RAG CHAT ---
  Future<String> getAnswerWithRAG(String userMessage) async {
    try {
      // Ensure initialization (non-blocking if it fails)
      if (!_isInitialized) {
        try {
          await initialize();
        } catch (e) {
          debugPrint(
            '⚠️ RAG initialization failed, continuing without notes: $e',
          );
          _isInitialized = true; // Mark as initialized to prevent retries
        }
      }

      String? context;
      try {
        context = await vectorStore.search(userMessage);
      } catch (e) {
        debugPrint('⚠️ Vector search failed, using direct query: $e');
        context = null;
      }

      // 2. Build Prompt
      String prompt;
      if (context != null) {
        prompt =
            """
        You are StudyPal, an intelligent AI study assistant. Use the following CONTEXT from the user's notes to answer.
        
        CONTEXT:
        "$context"
        
        USER QUESTION:
        "$userMessage"
        
        Answer naturally and helpfully. If the context answers it, use it. If not, use general knowledge.
        """;
      } else {
        prompt =
            """
        You are StudyPal, an intelligent AI study assistant designed to help students learn.
        
        USER QUESTION:
        "$userMessage"
        
        Answer naturally and helpfully based on your knowledge.
        """;
      }

      // 3. Get Answer
      final response = await gemini
          .prompt(parts: [Part.text(prompt)])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );
      return response?.output ?? "I couldn't think of an answer.";
    } on TimeoutException catch (e) {
      debugPrint('❌ Chat timeout: $e');
      return "Request timed out. Please check your internet connection and try again.";
    } catch (e) {
      debugPrint('❌ Chat error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error details: ${e.toString()}');

      final errorString = e.toString().toLowerCase();

      // Check for rate limit (429 error)
      if (errorString.contains('429') || errorString.contains('rate limit')) {
        return "⏳ Too many requests! Please wait 60 seconds before trying again.\n\nFree tier limits:\n• 15 requests/minute\n• 1,500 requests/day";
      } else if (errorString.contains('api key') ||
          errorString.contains('api_key')) {
        return "API key error. Please check your Gemini configuration.";
      } else if (errorString.contains('quota') ||
          errorString.contains('quota')) {
        return "Daily quota exceeded. Please try again tomorrow (resets at midnight PST).";
      } else if (errorString.contains('network') ||
          errorString.contains('socketexception')) {
        return "Network error. Please check your internet connection.";
      } else if (errorString.contains('permission_denied')) {
        return "Permission denied. Please check your Gemini API permissions.";
      }
      return "Sorry, I encountered an error: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}";
    }
  }

  // --- ADD KNOWLEDGE ---
  // Call this to save new facts to your database
  Future<void> learnFact(String fact) async {
    try {
      await vectorStore.addNote(fact);
    } catch (e) {
      debugPrint('❌ Failed to save fact: $e');
      rethrow;
    }
  }

  // --- IMAGE CHAT ---
  Stream<String> analyzeImageStream(String textPrompt, Uint8List imageBytes) {
    return gemini
        .promptStream(
          parts: [
            Part.text(textPrompt),
            Part.inline(
              InlineData(
                mimeType: 'image/jpeg',
                data: base64Encode(imageBytes),
              ),
            ),
          ],
          model: 'gemini-1.5-flash',
        )
        .map((event) => event?.output ?? "");
  }

  Future<String?> captureUserDetail(String userMessage) async {
    final original = userMessage.trim();
    if (original.isEmpty) return null;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      final normalized = original.replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = normalized.toLowerCase();
      final responses = <String>[];

      final nameMatch = RegExp(
        r'\bmy name is\s+([a-zA-Z ]{2,})',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (nameMatch != null) {
        final name = nameMatch.group(1)?.trim();
        if (name != null && name.isNotEmpty) {
          await learnFact("User profile: name is $name.");
          responses.add("Nice to meet you, $name! I'll remember your name.");
        }
      }

      final classesMatch = RegExp(
        r'\bi have\s+(\d+)\s+classes?',
      ).firstMatch(lower);
      if (classesMatch != null) {
        final count = classesMatch.group(1);
        if (count != null) {
          await learnFact("User profile: enrolled in $count classes.");
          responses.add("Got it! You're currently taking $count classes.");
        }
      }

      final pendingAssignmentsMatch = RegExp(
        r'\bmy pending assignments? (are|is)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (pendingAssignmentsMatch != null) {
        final details = pendingAssignmentsMatch.group(2)?.trim();
        if (details != null && details.isNotEmpty) {
          await learnFact("User assignments pending: $details.");
          responses.add("Thanks! I noted your pending assignments: $details.");
        }
      }

      final dueQuizzesMatch = RegExp(
        r'\b(my|i have) (pending|due) quizzes?\s*(on|are)?\s*(.+)',
        caseSensitive: false,
      ).firstMatch(normalized);
      if (dueQuizzesMatch != null) {
        final quizzes = dueQuizzesMatch.group(4)?.trim();
        if (quizzes != null && quizzes.isNotEmpty) {
          await learnFact("User quizzes pending: $quizzes.");
          responses.add(
            "Understood. I'll remind you about these quizzes: $quizzes.",
          );
        }
      }

      if (responses.isEmpty) {
        return null;
      }

      if (responses.length == 1) {
        return responses.first;
      }

      return responses.join(' ');
    } catch (e) {
      return "I tried to save that detail but ran into an issue: $e";
    }
  }
}
