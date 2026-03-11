class AuthService {
  // Simulate a successful signup
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Return a dummy success response
    return {
      'success': true,
      'message': 'Signup successful',
      'data': {
        'user': {
          'id': 'dummy_user_123',
          'email': email,
          'name': name,
          'createdAt': DateTime.now().toIso8601String(),
        },
        'token': 'dummy_jwt_token_1234567890',
      }
    };
  }

  // Simulate a successful login
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check for demo credentials
    if (email == 'demo@example.com' && password == 'password') {
      return {
        'success': true,
        'message': 'Login successful',
        'data': {
          'user': {
            'id': 'demo_user_123',
            'email': email,
            'name': 'Demo User',
            'createdAt': '2023-01-01T00:00:00.000Z',
          },
          'token': 'demo_jwt_token_1234567890',
        }
      };
    }

    // Default success response for any other credentials
    return {
      'success': true,
      'message': 'Login successful',
      'data': {
        'user': {
          'id': 'dummy_user_123',
          'email': email,
          'name': email.split('@').first,
          'createdAt': DateTime.now().toIso8601String(),
        },
        'token': 'dummy_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
      }
    };
  }

  // Simulate getting the current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'id': 'dummy_user_123',
      'email': 'user@example.com',
      'name': 'Test User',
      'createdAt': '2023-01-01T00:00:00.000Z',
    };
  }

  // Simulate sign out
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // No-op for dummy implementation
  }

  // Simulate password reset
  Future<Map<String, dynamic>> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'message': 'Password reset email sent to $email',
    };
  }
}
