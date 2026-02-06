import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {

    on<AppStarted>((event, emit) async {
      emit(AuthLoading());
      final savedStep = await authRepository.getRegistrationStep();
      if (savedStep != null) {
        if (savedStep['step'] == 'otp') {
          emit(AuthOtpSent(savedStep['data']!));
          return;
        } else if (savedStep['step'] == 'profile') {
          String suffix = DateTime.now().millisecond.toString();
          emit(AuthProfileIncomplete("${savedStep['data']}_$suffix"));
          return;
        }
      }
      final isLoggedIn = await authRepository.isLoggedIn();
      if (isLoggedIn) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        // FIX: Capture response to see if we got a token or need OTP
        final response = await authRepository.login(event.email, event.password);

        if (response.containsKey('accessToken')) {
          // Direct Login (No 2FA required by server)
          emit(AuthAuthenticated());
        } else {
          // 2FA flow (only if server didn't send token)
          await authRepository.saveRegistrationStep('otp', event.email);
          emit(AuthOtpSent(event.email));
        }
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.register(
          firstName: event.firstName,
          lastName: event.lastName,
          email: event.email,
          phone: event.phone,
          password: event.password,
          gender: event.gender,
          dob: event.dob,
        );
        emit(AuthOtpSent(event.email));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<VerifyOtpRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        // Use specific method based on context (Login vs Register)
        if (event.isLogin) {
          await authRepository.verifyLoginOtp(event.identifier, event.otp);
          emit(AuthAuthenticated());
        } else {
          await authRepository.verifyRegisterOtp(event.identifier, event.otp);
          // For registration, we might need to complete profile next
          emit(AuthProfileIncomplete(event.identifier.split('@')[0]));
        }
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<ResendOtpRequested>((event, emit) async {
      try {
        await authRepository.resendOtp(event.identifier);
      } catch (e) {
        // Silent catch for resend, or emit failure if critical
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<ForgotPasswordRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.forgotPassword(event.email);
        emit(AuthPasswordResetEmailSent(event.email));
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<ResetPasswordRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.resetPassword(
            email: event.email,
            otp: event.otp,
            newPassword: event.newPassword
        );
        emit(AuthPasswordResetSuccess());
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    on<CheckUsernameRequested>((event, emit) async {
      final isAvailable = await authRepository.checkUsername(event.username);
      emit(AuthUsernameChecked(isAvailable));
    });

    on<CompleteProfileRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.completeProfile(
          username: event.username,
          bio: event.bio,
          profilePicture: event.profilePicture,
          coverPhoto: event.coverPhoto,
          interests: event.interests,
        );
        emit(AuthAuthenticated());
      } catch (e) {
        emit(AuthFailure(e.toString().replaceAll("Exception: ", "")));
      }
    });

    // on<LogoutRequested>((event, emit) async {
    //   await authRepository.logout();
    //   emit(AuthUnauthenticated());
    // });
  }
}