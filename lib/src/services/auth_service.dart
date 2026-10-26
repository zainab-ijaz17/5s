import 'api_service.dart';
import '../util/jwt_util.dart';
import 'connectivity_service.dart';
import 'session_service.dart';

class AuthService {
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/auth/login',
      {'email': email, 'password': password},
      auth: false,
    );
    final data = Map<String, dynamic>.from(response['data'] ?? {});
    final token = data['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Login succeeded but token is missing.');
    }
    await ApiService.setAccessToken(token);

    final refreshToken = data['refreshToken']?.toString() ??
        data['refresh_token']?.toString();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await ApiService.setRefreshToken(refreshToken);
    }

    return data;
  }

  /// Refreshes access token when close to expiry (requires connectivity).
  Future<void> ensureValidAccessToken() async {
    final access = await ApiService.getAccessToken();
    if (access == null || access.isEmpty) {
      throw Exception('No saved session token.');
    }

    if (!JwtUtil.isExpired(access)) return;

    if (!await ConnectivityService.instance.isOnline()) {
      // Allow short grace period offline if token not fully expired yet.
      final exp = JwtUtil.expiry(access);
      if (exp != null && DateTime.now().isBefore(exp)) return;
      throw Exception('Session expired. Connect to internet to refresh login.');
    }

    await refreshAccessToken();
  }

  Future<void> refreshAccessToken() async {
    final refresh = await ApiService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw Exception(
        'Session expired and no refresh token available. Please sign in again.',
      );
    }

    final response = await ApiService.post(
      '/auth/refresh',
      {'refreshToken': refresh},
      auth: false,
    );

    final data = Map<String, dynamic>.from(response['data'] ?? response);
    final newAccess = data['accessToken']?.toString() ??
        data['access_token']?.toString();
    if (newAccess == null || newAccess.isEmpty) {
      throw Exception('Token refresh failed: missing access token.');
    }
    await ApiService.setAccessToken(newAccess);

    final newRefresh = data['refreshToken']?.toString() ??
        data['refresh_token']?.toString();
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await ApiService.setRefreshToken(newRefresh);
    }
  }

  Future<void> signOut() async {
    await SessionService.instance.clearSession();
  }
}
