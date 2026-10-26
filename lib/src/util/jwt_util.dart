import 'dart:convert';

class JwtUtil {
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static DateTime? expiry(String token) {
    final payload = decodePayload(token);
    final exp = payload?['exp'];
    if (exp is int) return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    }
    return null;
  }

  static bool isExpired(String token, {Duration leeway = const Duration(minutes: 2)}) {
    final exp = expiry(token);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp.subtract(leeway));
  }
}
