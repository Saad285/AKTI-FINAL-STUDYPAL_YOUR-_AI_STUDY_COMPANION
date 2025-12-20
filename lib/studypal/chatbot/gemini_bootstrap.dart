import 'package:flutter/foundation.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'gemini_config.dart';

class GeminiBootstrap {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;

    try {
      if (GeminiConfig.apiKey == 'YOUR_API_KEY_HERE') {
        debugPrint(
          '⚠️ WARNING: Using placeholder API key. Please update gemini_config.dart with your actual API key.',
        );
      }

      Gemini.init(apiKey: GeminiConfig.apiKey);
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing Gemini: $e');
    }
  }
}
