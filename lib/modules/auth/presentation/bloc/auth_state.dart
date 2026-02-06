import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {}

class AuthOtpSent extends AuthState {
  final String identifier;
  AuthOtpSent(this.identifier);
}

class AuthProfileIncomplete extends AuthState {
  final String suggestedUsername;
  AuthProfileIncomplete(this.suggestedUsername);
}

// NEW: Password Reset States
class AuthPasswordResetEmailSent extends AuthState {
  final String email;
  AuthPasswordResetEmailSent(this.email);
}

class AuthPasswordResetSuccess extends AuthState {}

class AuthUsernameChecked extends AuthState {
  final bool isAvailable;
  AuthUsernameChecked(this.isAvailable);
  @override
  List<Object> get props => [isAvailable];
}

class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
  @override
  List<Object> get props => [error];
}