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

  Future<void> _ensureDefaultQuestionsInFirestore() async {
    final snapshot = await _questionsCollection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final defaultQuestions = _getDefaultQuestions();
    for (int i = 0; i < defaultQuestions.length; i++) {
      final question = Map<String, dynamic>.from(defaultQuestions[i]);
      question['order'] = i + 1;
      await _questionsCollection.add(question);
    }
  }

  Future<List<Map<String, dynamic>>> getQuestions() async {
    try {
      print('Fetching questions from Firestore...');
      await _ensureDefaultQuestionsInFirestore();
      final snapshot = await _questionsCollection.orderBy('order').get();
      print(
          'Firestore query completed. Found ${snapshot.docs.length} documents.');

      if (snapshot.docs.isEmpty) {
        print('No documents in Firestore, using default questions directly...');
        return _getDefaultQuestions();
      }

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

      // If older environments already have a non-empty collection but the defaults
      // were never seeded, make sure at least the 10 default questions exist.
      // We treat a question as a default if its text matches.
      final defaultQuestions = _getDefaultQuestions();
      final existingTexts = questions
          .map((q) => (q['question'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      final missingDefaults = defaultQuestions
          .map((q) => (q['question'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty && !existingTexts.contains(t))
          .toList();

      if (missingDefaults.isNotEmpty) {
        // Seed missing defaults at the start in a stable order.
        for (int i = 0; i < defaultQuestions.length; i++) {
          final dq = defaultQuestions[i];
          final text = (dq['question'] ?? '').toString().trim();
          if (text.isEmpty || existingTexts.contains(text)) continue;
          final dataToSave = Map<String, dynamic>.from(dq);
          dataToSave['order'] = i + 1;
          await _questionsCollection.add(dataToSave);
          existingTexts.add(text);
        }

        final resnapshot = await _questionsCollection.orderBy('order').get();
        final requeried = resnapshot.docs.map((doc) {
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

          data.forEach((key, value) {
            if (!normalized.containsKey(key)) normalized[key] = value;
          });

          return normalized;
        }).toList();

        print('Processed ${requeried.length} questions from Firestore.');
        return requeried;
      }

      print('Processed ${questions.length} questions from Firestore.');
      return questions;
    } catch (e) {
      print('Firestore error: $e');
      print('Falling back to default questions...');
      // Fallback to default questions if Firestore fails
      return _getDefaultQuestions();
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
    try {
      final snapshot = await _questionsCollection.limit(1).get();
      if (snapshot.docs.isEmpty) {
        // Add default questions if collection is empty
        final defaultQuestions = _getDefaultQuestions();
        for (int i = 0; i < defaultQuestions.length; i++) {
          final question = Map<String, dynamic>.from(defaultQuestions[i]);
          question['order'] = i + 1;
          await _questionsCollection.add(question);
        }
      }
    } catch (e) {
      print('Error initializing default questions: $e');
    }
  }

  List<Map<String, dynamic>> _getDefaultQuestions() {
    print('Getting default questions...');
    final defaultQuestions = [
      {
        'question':
            '1. Are only the necessary tools, materials, and documents kept at the workplace?',
        'category': 'SORT',
        'details':
            'Remove all unused, damaged, or obsolete items. Keep only what is essential for daily operations.'
      },
      {
        'question':
            '2. Is there a system in place (e.g., red tag) to identify and remove unwanted items?',
        'category': 'SORT',
        'details':
            'Use tags or markings to highlight unnecessary items for removal or relocation.'
      },
      {
        'question':
            '3. Are all frequently used items placed in fixed, labeled, and easily accessible locations?',
        'category': 'SET',
        'details':
            'Assign a standard location for each item with labels or color codes to help everyone find and return them easily.'
      },
      {
        'question':
            '4. Are visual controls (e.g., labels, floor markings, color codes) properly implemented and maintained?',
        'category': 'SET',
        'details':
            'Visual organization helps identify where things belong and when something is missing.'
      },
      {
        'question':
            '5. Is workplace, including tools and machines, cleaned regularly as part of routine?',
        'category': 'SHINE',
        'details':
            'Cleaning should be done daily or shift-wise, not occasionally. Keep tools and equipment ready for use.'
      },
      {
        'question':
            '6. Is there a clear cleaning schedule with responsibilities assigned?',
        'category': 'SHINE',
        'details':
            'Define who cleans what, how often, and ensure accountability through checklists or cleaning logs.'
      },
      {
        'question':
            '7. Are standard procedures or checklists available for cleaning and organizing activities?',
        'category': 'STANDARDIZE',
        'details':
            'Use visual SOPs or step-by-step instructions to ensure everyone follows the same method.'
      },
      {
        'question':
            '8. Are standard markings, labels, and layouts consistent across all areas?',
        'category': 'STANDARDIZE',
        'details':
            'Consistency helps reduce confusion and supports easy compliance with 5S standards.'
      },
      {
        'question':
            '9. Are regular audits or trainings conducted to sustain 5S practices?',
        'category': 'SUSTAIN',
        'details':
            'Periodic checks and refresher sessions keep teams aligned and improve discipline.'
      },
      {
        'question':
            '10. Is there a system for recognizing and rewarding employees who maintain 5S standards?',
        'category': 'SUSTAIN',
        'details':
            'Appreciation or small rewards encourage ownership and long-term 5S culture.'
      }
    ];
    print('Generated ${defaultQuestions.length} default questions');
    return defaultQuestions;
  }
}
