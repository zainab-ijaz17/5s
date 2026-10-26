import 'package:http/http.dart' as http;

Future<http.Client> createApiHttpClient({
  required Duration connectTimeout,
  required Duration idleTimeout,
}) async {
  return http.Client();
}
