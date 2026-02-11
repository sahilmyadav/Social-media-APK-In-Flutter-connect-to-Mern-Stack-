import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import 'package:permission_handler/permission_handler.dart'; // Added for permissions
import 'package:photo_manager/photo_manager.dart'; // Added for manageStoragePermission

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
  Future<Map<String, dynamic>> verifyLoginOtp(
      String identifier, String otp) async {
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
  Future<Map<String, dynamic>> verifyRegisterOtp(
      String identifier, String otp) async {
    try {
      final response =
          await _apiClient.dio.post('/users/verify-register', data: {
        "identifier": identifier,
        "otp": otp,
      });
      return await _handleAuthResponse(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Helper to handle token storage
  Future<Map<String, dynamic>> _handleAuthResponse(
      Map<String, dynamic> data) async {
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
      final Map<String, dynamic> data =
          isEmail ? {"email": identifier} : {"phone": identifier};

      await _apiClient.dio.post('/users/resend-otp', data: data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<bool> checkUsername(String username) async {
    try {
      final response = await _apiClient.dio.get('/users/check-username',
          queryParameters: {'username': username});
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
      await _apiClient.dio
          .post('/users/forgot-password', data: {"email": email});
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> resetPassword(
      {required String email,
      required String otp,
      required String newPassword}) async {
    try {
      await _apiClient.dio.post('/users/reset-password',
          data: {"email": email, "otp": otp, "newPassword": newPassword});
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

  @override
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ (API 33) uses specific media permissions
      // We check device version indirectly by checking if photos permission is available/needed
      // But typically we can just check SDK version or try generic logic.
      // A common pattern:
      /*
      if (await Permission.storage.request().isGranted) return true;
      */

      // Better approach for Android 13+:
      // DeviceInfoPlugin info = DeviceInfoPlugin();
      // AndroidDeviceInfo androidInfo = await info.androidInfo;
      // if (androidInfo.version.sdkInt >= 33) ...

      // Simpler check: Request Photos first (Android 13+), if not applicable/granted, check Storage.
      // actually, permission_handler handles SDK checks internally mostly.

      // Let's try separate checks based on common android storage logic

      // Check for Photos (Android 13+)
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted) return true;

      // Check for Storage (Android < 13)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      // Request logic
      // We assume if one fails/is restricted, we try the valid one.
      // BUT, we don't want to request *both* sequentially if not needed.

      // Heuristic: Try to request 'photos' first (harmless on old android? no, might be invalid)
      // Safest: Use device info, but we can't import device_info_plus just for this if not already there.
      // Let's assume standard behavior:

      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();

      if (statuses[Permission.storage] == PermissionStatus.granted ||
          statuses[Permission.photos] == PermissionStatus.granted) {
        return true;
      }

      return false;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  @override
  Future<void> manageStoragePermission() async {
    if (Platform.isIOS || (Platform.isAndroid)) {
      // PhotoManager handles the device version check internally usually,
      // or presentLimited just does nothing on unsupported versions.
      await PhotoManager.presentLimited();
    }
  }
}
