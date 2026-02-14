import 'dart:io';

abstract class AuthRepository {
  // FIX: Changed return type to Future<Map<String, dynamic>> to return Token/User data
  Future<Map<String, dynamic>> login(String email, String password);

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String gender,
    required String dob,
  });

  Future<Map<String, dynamic>> verifyLoginOtp(String identifier, String otp);
  Future<Map<String, dynamic>> verifyRegisterOtp(String identifier, String otp);

  Future<void> resendOtp(String identifier);

  Future<bool> checkUsername(String username);

  Future<void> completeProfile({
    required String username,
    String? bio,
    File? profilePicture,
    File? coverPhoto,
    List<String>? interests,
  });

  Future<void> forgotPassword(String email);
  Future<void> resetPassword(
      {required String email,
      required String otp,
      required String newPassword});

  Future<bool> isLoggedIn();
  Future<void> logout();

  Future<void> saveRegistrationStep(String step, String data);
  Future<Map<String, String>?> getRegistrationStep();
  Future<void> clearRegistrationStep();

  // --- NEW: Request Storage/Photos Permission ---
  Future<bool> requestStoragePermission();
  Future<void> manageStoragePermission(); // Added for Manage Access
}
