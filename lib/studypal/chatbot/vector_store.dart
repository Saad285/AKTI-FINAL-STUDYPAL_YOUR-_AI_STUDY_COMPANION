import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class Document {
  final String content;
  final List<double> embedding;

  Document({required this.content, required this.embedding});

  // Convert Firestore data to App data
  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      content: map['content'] ?? '',
      // Safely convert Firestore list to List<double>
      embedding: List<double>.from(
        map['embedding']?.map((e) => e.toDouble()) ?? [],
      ),
    );
  }
}

class VectorStore {
  late final Gemini gemini;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  List<Document> _localCache = [];
  bool isLoaded = false;

  VectorStore() {
    gemini = Gemini.instance;
  }

  /// 1. INITIALIZE: Fetch notes from Firebase
  Future<void> fetchNotes() async {
    if (isLoaded) return;
    try {
      debugPrint("📥 Fetching notes from Firestore...");

      // Limit to 50 notes for better performance and memory usage
      final snapshot = await firestore
          .collection('study_notes')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Failed to fetch notes'),
          );

      if (snapshot.docs.isEmpty) {
        debugPrint("⚠️ No notes found in Firestore. Add some notes first!");
      }

      _localCache = snapshot.docs
          .map((doc) {
            try {
              return Document.fromMap(doc.data());
            } catch (e) {
              debugPrint("⚠️ Skipping invalid document: $e");
              return null;
            }
          })
          .whereType<Document>()
          .toList();

      isLoaded = true;
      debugPrint("✅ Loaded ${_localCache.length} notes from Firebase.");
    } on TimeoutException catch (e) {
      debugPrint("❌ Timeout loading notes: $e");
      _localCache = [];
      isLoaded = true;
    } on FirebaseException catch (e) {
      debugPrint("❌ Firebase error loading notes: ${e.code} - ${e.message}");
      _localCache = [];
      isLoaded = true;
    } catch (e) {
      debugPrint("❌ Error loading notes: $e");
      // Continue with empty cache instead of failing
      _localCache = [];
      isLoaded = true;
    }
  }

  /// 2. ADD NOTE: Optimized for Firebase free tier
  Future<void> addNote(String text) async {
    if (text.trim().isEmpty) {
      debugPrint("⚠️ Cannot add empty note");
      return;
    }

    try {
      debugPrint(
        "🔄 Generating embedding for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...",
      );

      final response = await gemini
          .batchEmbedContents([text])
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Embedding generation timeout'),
          );

      final vector = response?.first?.map((e) => e.toDouble()).toList();

      if (vector == null || vector.isEmpty) {
        debugPrint("❌ Failed to generate embedding");
        throw Exception('Empty embedding vector received');
      }

      // Save to Firestore
      await firestore
          .collection('study_notes')
          .add({
            'content': text,
            'embedding': vector,
            'created_at': FieldValue.serverTimestamp(),
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Failed to save note to Firestore'),
          );

      // Update local cache
      _localCache.add(Document(content: text, embedding: vector));
      debugPrint(
        "✅ Saved note successfully (${_localCache.length} total notes)",
      );
    } on TimeoutException catch (e) {
      debugPrint("❌ Timeout error: $e");
      throw Exception('Operation timed out. Please check your connection.');
    } on FirebaseException catch (e) {
      debugPrint("❌ Firebase error saving note: ${e.code} - ${e.message}");
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied. Check Firestore security rules.');
      } else if (e.code == 'unavailable') {
        throw Exception('Network error. Please check your connection.');
      }
      throw Exception('Failed to save note: ${e.message}');
    } catch (e) {
      debugPrint("❌ Error saving note: $e");
      if (e.toString().contains('API key') || e.toString().contains('quota')) {
        throw Exception(
          'API error. Please check your Gemini API key and quota.',
        );
      } else if (e.toString().contains('network')) {
        throw Exception(
          'Network error. Please check your internet connection.',
        );
      }
      rethrow;
    }
  }

  /// 3. SEARCH: Fixes 'values' error
  Future<String?> search(String query) async {
    if (_localCache.isEmpty) await fetchNotes();
    if (_localCache.isEmpty) return null;

    try {
      final response = await gemini.batchEmbedContents([query]);

      // FIX: response?.first IS the vector.
      final queryVector = response?.first?.map((e) => e.toDouble()).toList();

      if (queryVector == null) return null;

      Document? bestDoc;
      double highestScore = -1.0;

      for (var doc in _localCache) {
        double score = _cosineSimilarity(queryVector, doc.embedding);
        if (score > highestScore) {
          highestScore = score;
          bestDoc = doc;
        }
      }

      // Threshold: 65% similarity required (0.0 = no match, 1.0 = perfect match)
      if (highestScore > 0.65) {
        debugPrint(
          "✅ Found relevant note (similarity: ${(highestScore * 100).toStringAsFixed(1)}%)",
        );
        return bestDoc?.content;
      }

      debugPrint(
        "🔍 No relevant notes found (best match: ${(highestScore * 100).toStringAsFixed(1)}%)",
      );
      return null;
    } catch (e) {
      debugPrint("❌ Search error: $e");
      return null;
    }
  }

  // Math: Compare two vectors
  double _cosineSimilarity(List<double> vecA, List<double> vecB) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    if (vecA.length != vecB.length) return 0.0;

    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
