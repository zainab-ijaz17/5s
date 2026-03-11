import 'package:flutter/foundation.dart';
import 'question_service.dart';

class InitService {
  static Future<void> initializeServices() async {
    try {
      // Initialize default questions if they don't exist
      await QuestionService().initializeDefaultQuestions();
      
      if (kDebugMode) {
        print('✅ Services initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing services: $e');
      }
    }
  }
}
