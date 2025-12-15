import 'dart:math';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatLogic {
  final Gemini gemini = Gemini.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // --- RETRY HELPER (Network issues handle karne ke liye) ---
  Future<T?> _withRetry<T>(Future<T?> Function() fn, {int retries = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        final msg = e.toString();
        // Agar rate limit (429) aye toh wait karke retry karega
        if (attempt <= retries && msg.contains('429')) {
          final wait = Duration(seconds: 1 << (attempt - 1));
          await Future.delayed(wait);
          continue;
        }
        rethrow;
      }
    }
  }

  // --- FUNCTION 1: Get Answer (RAG - Optimized & Fixed) ---
  Future<String> getAnswer(String userQuestion) async {
    // Validation: Agar sawal khali hai toh API call mat karo
    if (userQuestion.trim().isEmpty) {
      return "Please enter a valid question.";
    }

    try {
      // [FIX HERE] Model Name: 'text-embedding-004' use karna zaroori hai
      final rawResult = await _withRetry(
        () =>
            gemini.embedContent(userQuestion, modelName: 'text-embedding-004'),
      );

      List<double> queryVector = [];

      // Safe Type Casting
      if (rawResult != null) {
        // Check agar response list hai
        if (rawResult is List) {
          queryVector = rawResult.map((e) => (e as num).toDouble()).toList();
        } else {
          return "Error: Internal AI Format Mismatch.";
        }
      } else {
        return "Sorry, I couldn't understand the question (Embedding failed).";
      }

      // 2. Fetch Notes from Firebase
      QuerySnapshot snapshot = await firestore.collection('notes').get();

      List<Map<String, dynamic>> scoredNotes = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['vector'] != null) {
          List<double> noteVector = (data['vector'] as List)
              .map((e) => (e as num).toDouble())
              .toList();

          double score = _calculateSimilarity(queryVector, noteVector);

          // Threshold 0.60
          if (score > 0.60) {
            scoredNotes.add({'content': data['content'], 'score': score});
          }
        }
      }

      // 3. Top 3 Matches Logic
      scoredNotes.sort((a, b) => b['score'].compareTo(a['score']));
      var topMatches = scoredNotes.take(3).toList();

      String contextString = "";
      if (topMatches.isNotEmpty) {
        contextString = "Relevant Info from Notes:\n";
        for (var note in topMatches) {
          contextString += "- ${note['content']}\n";
        }
      }

      // 4. Prompt Construction
      String fullPrompt =
          "You are 'Study Pal', a helpful classroom assistant.\n"
          "Answer the user's question using the notes provided below. "
          "If the answer isn't in the notes, say 'I couldn't find this in your notes' and then try to answer from general knowledge.\n\n"
          "$contextString\n"
          "User Question: $userQuestion\n"
          "Answer:";

      final response = await _withRetry(
        () => gemini.prompt(parts: [Part.text(fullPrompt)]),
      );
      return response?.output ?? "Sorry, no response from AI.";
    } catch (e) {
      print("Error in getAnswer: $e");
      // UI par exact error dikhane ke liye
      return "Error: Something went wrong. Details: $e";
    }
  }

  // --- FUNCTION 2: Save Note ---
  Future<void> saveNoteToMemory(String title, String content) async {
    // Validation: Khali note save mat karo
    if (content.trim().isEmpty) return;

    try {
      // [FIX HERE TOO] Note save karte waqt bhi naya model use karo
      final rawEmbedding = await _withRetry(
        () => gemini.embedContent(content, modelName: 'text-embedding-004'),
      );

      if (rawEmbedding != null) {
        // Safe casting
        List<double> embedding = [];
        if (rawEmbedding is List) {
          embedding = rawEmbedding.map((e) => (e as num).toDouble()).toList();
        }

        if (embedding.isNotEmpty) {
          await firestore.collection('notes').add({
            'title': title,
            'content': content,
            'vector': embedding,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print("Error saving note: $e");
      throw e;
    }
  }

  // --- MATHS HELPER (Cosine Similarity) ---
  double _calculateSimilarity(List<double> vecA, List<double> vecB) {
    var dotProduct = 0.0;
    var normA = 0.0;
    var normB = 0.0;

    // Safety: Use the smaller length to avoid index out of bounds
    int length = min(vecA.length, vecB.length);

    for (int i = 0; i < length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
