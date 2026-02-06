import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/local_storage/hive_helper.dart'; // Import HiveHelper
import 'injection_container.dart' as di;
import 'modules/auth/presentation/bloc/auth_bloc.dart';
import 'modules/auth/presentation/bloc/auth_event.dart';
import 'modules/auth/presentation/bloc/auth_state.dart';
import 'modules/auth/presentation/screens/login_screen.dart';
import 'modules/auth/presentation/screens/otp_verification_screen.dart';
import 'modules/auth/presentation/screens/complete_profile_screen.dart';
import 'modules/post/presentation/bloc/upload_bloc.dart';
import 'presentation/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Dependency Injection
  await di.init();

  // 2. CRITICAL: Initialize Hive before app runs
  await HiveHelper.init();

  // 3. OPTIONAL: Uncomment this ONCE if crashes persist, then comment it out again.
  // await HiveHelper.clearAll();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<AuthBloc>()..add(AppStarted()),
        ),

        BlocProvider(
          create: (_) => di.sl<UploadBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'ClickME',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const MainScreen();
        } else if (state is AuthOtpSent) {
          return OtpVerificationScreen(
              identifier: state.identifier, isLogin: false);
        } else if (state is AuthProfileIncomplete) {
          return CompleteProfileScreen(
              suggestedUsername: state.suggestedUsername);
        } else if (state is AuthLoading && state is! AuthFailure) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
    );
  }
}