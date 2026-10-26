import 'api_service.dart';

class UserService {
  static Future<void> updateUserBusinessUnit({
    required String userId,
    required String businessUnit,
    required String section,
  }) async {
    await ApiService.patch('/users/$userId', {
      'businessUnit': businessUnit,
      'section': section,
    });
  }

  static Future<Map<String, dynamic>?> getUserByEmployeeId(int employeeId) async {
    try {
      final response = await ApiService.get('/users/employee/$employeeId');
      if (response == null || response is! Map<String, dynamic>) return null;
      return response;
    } catch (e) {
      print('Error in getUserByEmployeeId: $e');
      return null;
    }
  }
}
