import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Future<http.Client> createApiHttpClient({
  required Duration connectTimeout,
  required Duration idleTimeout,
}) async {
  HttpClient ioHttpClient;

  try {
    final context = SecurityContext(withTrustedRoots: true);
    final certData = await rootBundle.load('assets/company_ca.crt');
    context.setTrustedCertificatesBytes(certData.buffer.asUint8List());
    ioHttpClient = HttpClient(context: context);
  } catch (_) {
    // SecurityContext is unavailable on some embedders; use system trust store.
    ioHttpClient = HttpClient();
  }

  ioHttpClient
    ..connectionTimeout = connectTimeout
    ..idleTimeout = idleTimeout;

  return IOClient(ioHttpClient);
}
