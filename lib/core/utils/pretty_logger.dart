// lib/core/utils/pretty_logger.dart
import 'package:flutter/foundation.dart';

class PrettyLogger {
  static void logRequest(String method, String url, {dynamic body}) {
    debugPrint('\x1B[34m[HTTP REQUEST] 🔵 $method $url\x1B[0m');
    if (body != null) debugPrint('\x1B[34m[BODY] $body\x1B[0m');
  }

  static void logSuccess(String url, dynamic response) {
    debugPrint('\x1B[32m[HTTP SUCCESS] ✅ $url\x1B[0m');
    debugPrint('\x1B[32m[DATA] $response\x1B[0m');
  }

  static void logError(String url, String error, {dynamic responseBody}) {
    debugPrint('\x1B[31m[HTTP ERROR] ❌ $url\x1B[0m');
    debugPrint('\x1B[31m[ERROR MSG] $error\x1B[0m');
    if (responseBody != null) {
      debugPrint('\x1B[31m[SERVER RESPONSE] $responseBody\x1B[0m');
    }
  }
}