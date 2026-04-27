import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionService {
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  final CollectionReference _questionsCollection =
      FirebaseFirestore.instance.collection('questions');

  int _parseOrder(dynamic raw, {int fallback = 0}) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  Future<List<Map<String, dynamic>>> getQuestions() async {
    try {
      print('Fetching questions from Firestore...');
      final snapshot = await _questionsCollection.orderBy('order').get();
      print(
          'Firestore query completed. Found ${snapshot.docs.length} documents.');

      final questions = snapshot.docs.map((doc) {
        final raw = doc.data();
        final data =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

        final normalized = <String, dynamic>{
          'id': doc.id,
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


      print('Processed ${questions.length} questions from Firestore.');
      return questions;
    } catch (e) {
      print('Firestore error: $e');
      return [];
    }
  }

  Future<void> updateQuestion(
      String id, Map<String, dynamic> questionData) async {
    await _questionsCollection.doc(id).update(questionData);
  }

  Future<void> addQuestion(Map<String, dynamic> questionData) async {
    // Get the highest order value
    final snapshot = await _questionsCollection
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    int nextOrder = 1;
    if (snapshot.docs.isNotEmpty) {
      final raw = snapshot.docs.first.data();
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      nextOrder = _parseOrder(data['order'], fallback: 0) + 1;
    }

    final dataToSave = Map<String, dynamic>.from(questionData);
    dataToSave['order'] = nextOrder;
    await _questionsCollection.add(dataToSave);
  }

  Future<void> deleteQuestion(String id) async {
    await _questionsCollection.doc(id).delete();
  }

  Future<void> reorderQuestions(List<String> questionIds) async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < questionIds.length; i++) {
      final docRef = _questionsCollection.doc(questionIds[i]);
      batch.update(docRef, {'order': i + 1});
    }
    await batch.commit();
  }

  Future<void> initializeDefaultQuestions() async {
    // No-op: questions are fully managed via CRUD (Firestore collection).
  }
}
