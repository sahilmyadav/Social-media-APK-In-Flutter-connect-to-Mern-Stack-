import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient(this._dio, this._storage) {
    _dio.options.baseUrl = 'https://clikkme.in/api/v1';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // DEBUG: Print all API calls to terminal to see errors clearly
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Read token before every request
        final token = await _storage.read(key: 'accessToken');

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          // debugPrint("[API] Using Token: ${token.substring(0, 5)}...");
        } else {
          debugPrint("[API] No token found in storage.");
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // FIX: Handle 401 Unauthorized Loop
        if (e.response?.statusCode == 401) {
          debugPrint("[API] 401 Detected. Clearing invalid session data.");

          // 1. Clear bad tokens immediately
          await _storage.deleteAll();

          // 2. (Optional) You can add logic here to navigate to LoginScreen globally
          // For now, clearing storage ensures the next app restart asks for login.
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}