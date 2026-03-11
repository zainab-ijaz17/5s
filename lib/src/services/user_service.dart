import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> updateUserBusinessUnit({
    required String userId,
    required String businessUnit,
    required String section,
  }) async {
    await _firestore
        .collection('company')
        .doc('main')
        .collection('users')
        .doc(userId)
        .update({
      'business_unit': businessUnit,
      'section': section,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addAssessmentToUser({
    required String userId,
    required Map<String, dynamic> assessmentData,
  }) async {
    try {
      print('DEBUG: UserService.addAssessmentToUser called');
      print('DEBUG: userId: $userId');
      print('DEBUG: assessmentData: $assessmentData');

      await _firestore
          .collection('company')
          .doc('main')
          .collection('users')
          .doc(userId)
          .update({
        'assessments': FieldValue.arrayUnion([assessmentData]),
        'last_assessment_at': FieldValue.serverTimestamp(),
      });

      print('DEBUG: Assessment added successfully to Firestore');
    } catch (e) {
      print('DEBUG: Error in UserService.addAssessmentToUser: $e');
      rethrow;
    }
  }

  static Future<DocumentSnapshot?> getUserByEmployeeId(int employeeId) async {
    try {
      print('DEBUG: Searching for user with employeeId: $employeeId');

      final query = await _firestore
          .collection('company')
          .doc('main')
          .collection('users')
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      print('DEBUG: Query returned ${query.docs.length} documents');

      if (query.docs.isEmpty) {
        print(
            'DEBUG: No user found in new structure, checking old structure...');

        // Try old structure as fallback
        final oldQuery = await _firestore
            .collection('users')
            .where('employee_id', isEqualTo: employeeId.toString())
            .limit(1)
            .get();

        print(
            'DEBUG: Old structure query returned ${oldQuery.docs.length} documents');

        if (oldQuery.docs.isNotEmpty) {
          print(
              'DEBUG: Found user in old structure: ${oldQuery.docs.first.id}');
          return oldQuery.docs.first;
        }
      }

      if (query.docs.isNotEmpty) {
        print('DEBUG: Found user in new structure: ${query.docs.first.id}');
        return query.docs.first;
      }

      return null;
    } catch (e) {
      print('DEBUG: Error in getUserByEmployeeId: $e');
      return null;
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    await _firestore
        .collection('company')
        .doc('main')
        .collection('users')
        .doc(userId)
        .update(userData);
  }
}
