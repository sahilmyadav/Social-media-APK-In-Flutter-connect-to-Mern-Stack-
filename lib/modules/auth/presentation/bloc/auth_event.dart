import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class RegisterRequested extends AuthEvent {
  final String firstName, lastName, email, phone, password, gender, dob;
  RegisterRequested({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.gender,
    required this.dob,
  });
}

// FIX: Added isLogin to know which API endpoint to hit
class VerifyOtpRequested extends AuthEvent {
  final String identifier;
  final String otp;
  final bool isLogin;
  VerifyOtpRequested(this.identifier, this.otp, {required this.isLogin});
}

class ResendOtpRequested extends AuthEvent {
  final String identifier;
  ResendOtpRequested(this.identifier);
}

class ForgotPasswordRequested extends AuthEvent {
  final String email;
  ForgotPasswordRequested(this.email);
}

class ResetPasswordRequested extends AuthEvent {
  final String email;
  final String otp;
  final String newPassword;
  ResetPasswordRequested({required this.email, required this.otp, required this.newPassword});
}

class CheckUsernameRequested extends AuthEvent {
  final String username;
  CheckUsernameRequested(this.username);
}

class CompleteProfileRequested extends AuthEvent {
  final String username;
  final String? bio;
  final File? profilePicture;
  final File? coverPhoto;
  final List<String> interests;

  CompleteProfileRequested({
    required this.username,
    this.bio,
    this.profilePicture,
    this.coverPhoto,
    this.interests = const [],
  });
}

class AppStarted extends AuthEvent {}