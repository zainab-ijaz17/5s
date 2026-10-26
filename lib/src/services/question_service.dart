import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'connectivity_service.dart';

class QuestionService {
  static const String _cacheKey = 'questions_cache_v1';
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  int _parseOrder(dynamic raw, {int fallback = 0}) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  Future<List<Map<String, dynamic>>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<void> _saveCache(List<Map<String, dynamic>> questions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(questions));
  }

  Future<List<Map<String, dynamic>>> getQuestions() async {
    final online = await ConnectivityService.instance.isOnline();
    if (!online) {
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        print('Loaded ${cached.length} questions from offline cache');
        return cached;
      }
      throw Exception(
        'No internet and no cached questions. Connect once to download questions.',
      );
    }

    try {
      print('Fetching questions from Nest API...');
      final response = await ApiService.get('/questions');
      final list = (response is List)
          ? response
          : (response['data'] as List<dynamic>? ?? <dynamic>[]);

      final questions = list.map((raw) {
        final data =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

        final normalized = <String, dynamic>{
          'id': data['id']?.toString() ?? '',
          'question': data['question']?.toString() ?? '',
          'details': data['details']?.toString() ?? '',
          'category': data['category']?.toString() ?? 'SORT',
          'order': _parseOrder(data['order'], fallback: 0),
        };

        // Preserve any extra fields without breaking consumers.
        data.forEach((key, value) {
          if (!normalized.containsKey(key)) normalized[key] = value;
        });

        return normalized;
      }).toList();

      questions.sort(
        (a, b) => _parseOrder(a['order']).compareTo(_parseOrder(b['order'])),
      );

      print('Processed ${questions.length} questions from API.');
      if (questions.isNotEmpty) {
        await _saveCache(questions);
      }
      return questions;
    } catch (e) {
      print('Questions API error: $e');
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        print('Using cached questions after API error');
        return cached;
      }
      rethrow;
    }
  }

  Future<void> updateQuestion(
      String id, Map<String, dynamic> questionData) async {
    await ApiService.patch('/questions/$id', questionData);
  }

  Future<void> addQuestion(Map<String, dynamic> questionData) async {
    await ApiService.post('/questions', questionData);
  }

  Future<void> deleteQuestion(String id) async {
    await ApiService.delete('/questions/$id');
  }

  Future<void> reorderQuestions(List<String> questionIds) async {
    for (int i = 0; i < questionIds.length; i++) {
      await ApiService.patch('/questions/${questionIds[i]}', {'order': i + 1});
    }
  }

  Future<void> initializeDefaultQuestions() async {
    // No-op: questions are fully managed via CRUD (Firestore collection).
  }
}
