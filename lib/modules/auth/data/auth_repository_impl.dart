import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepositoryImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post('/users/login', data: {
        "email": email,
        "password": password,
      });

      // FIX: Check if token exists in response immediately
      if (response.data['data'] != null) {
        final data = response.data['data'];

        // If token exists, we are logged in! Save it.
        if (data['accessToken'] != null) {
          await _handleAuthResponse(data);
          return data; // Return data so Bloc knows we are authenticated
        }
      }

      // If no token, maybe 2FA is required? Return empty map or specific flag
      return response.data['data'] ?? {};

    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String gender,
    required String dob,
  }) async {
    try {
      await _apiClient.dio.post('/users/register', data: {
        "firstName": firstName,
        "lastName": lastName,
        "email": email,
        "phone": phone,
        "password": password,
        "gender": gender.toLowerCase(),
        "dob": dob,
      });
      await saveRegistrationStep('otp', email);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyLoginOtp(String identifier, String otp) async {
    try {
      final response = await _apiClient.dio.post('/users/verify-login', data: {
        "identifier": identifier,
        "otp": otp,
      });
      return await _handleAuthResponse(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyRegisterOtp(String identifier, String otp) async {
    try {
      final response = await _apiClient.dio.post('/users/verify-register', data: {
        "identifier": identifier,
        "otp": otp,
      });
      return await _handleAuthResponse(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Helper to handle token storage
  Future<Map<String, dynamic>> _handleAuthResponse(Map<String, dynamic> data) async {
    if (data['accessToken'] != null) {
      await _storage.write(key: 'accessToken', value: data['accessToken']);
    }
    if (data['refreshToken'] != null) {
      await _storage.write(key: 'refreshToken', value: data['refreshToken']);
    }
    if (data['user'] != null && data['user']['_id'] != null) {
      await _storage.write(key: 'userId', value: data['user']['_id']);
    }

    // Clear registration steps as we are fully logged in
    await clearRegistrationStep();

    return data['user'] ?? {};
  }

  @override
  Future<void> resendOtp(String identifier) async {
    try {
      // FIX: Server requires 'email' or 'phone', not 'identifier'
      final isEmail = identifier.contains('@');
      final Map<String, dynamic> data = isEmail
          ? {"email": identifier}
          : {"phone": identifier};

      await _apiClient.dio.post('/users/resend-otp', data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<bool> checkUsername(String username) async {
    try {
      final response = await _apiClient.dio.get('/users/check-username', queryParameters: {
        'username': username
      });
      return response.data['data']['available'] ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> completeProfile({
    required String username,
    String? bio,
    File? profilePicture,
    File? coverPhoto,
    List<String>? interests,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        "username": username,
        if (bio != null) "bio": bio,
      });

      if (interests != null) {
        for (var interest in interests) {
          formData.fields.add(MapEntry("interests[]", interest));
        }
      }

      if (profilePicture != null) {
        String fileName = profilePicture.path.split('/').last;
        formData.files.add(MapEntry(
          "profilePicture",
          await MultipartFile.fromFile(profilePicture.path, filename: fileName),
        ));
      }

      if (coverPhoto != null) {
        String fileName = coverPhoto.path.split('/').last;
        formData.files.add(MapEntry(
          "coverPhoto",
          await MultipartFile.fromFile(coverPhoto.path, filename: fileName),
        ));
      }

      await _apiClient.dio.post('/users/complete-profile', data: formData);
      await clearRegistrationStep();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _apiClient.dio.post('/users/forgot-password', data: {
        "email": email
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> resetPassword({required String email, required String otp, required String newPassword}) async {
    try {
      await _apiClient.dio.post('/users/reset-password', data: {
        "email": email,
        "otp": otp,
        "newPassword": newPassword
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'accessToken');
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  @override
  Future<void> saveRegistrationStep(String step, String data) async {
    await _storage.write(key: 'auth_step', value: step);
    await _storage.write(key: 'auth_data', value: data);
  }

  @override
  Future<Map<String, String>?> getRegistrationStep() async {
    final step = await _storage.read(key: 'auth_step');
    final data = await _storage.read(key: 'auth_data');
    if (step != null && data != null) {
      return {'step': step, 'data': data};
    }
    return null;
  }

  @override
  Future<void> clearRegistrationStep() async {
    await _storage.delete(key: 'auth_step');
    await _storage.delete(key: 'auth_data');
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return Exception("No Internet Connection. Please check your network.");
      }
      if (e.response != null) {
        final data = e.response?.data;
        if (data != null && data is Map) {
          if (data.containsKey('message')) {
            return Exception(data['message']);
          }
          if (data.containsKey('error')) {
            return Exception(data['error']);
          }
        }
      }
      return Exception("Something went wrong. Please try again.");
    }
    return Exception(e.toString());
  }
}