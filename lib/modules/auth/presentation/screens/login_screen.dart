import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'signup_screen.dart';
import 'otp_verification_screen.dart';
import 'forgot_password_screen.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../presentation/main_screen.dart';
import '../../../../core/utils/snackbar_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // FIX 1: Show Snackbar on Error
          if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          }
          // FIX 2: Navigate to OTP only if required
          else if (state is AuthOtpSent) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(identifier: state.identifier, isLogin: true)
            ));
          }
          // FIX 3: Direct Navigation to Feed if already authenticated (Token received)
          else if (state is AuthAuthenticated) {
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
                    (route) => false
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  // Logo / Title area
                  Center(
                    child: Text(
                        'ClickME',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Fredoka',
                            color: textColor
                        )
                    ),
                  ),
                  const SizedBox(height: 40),

                  Text("Email or Phone", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 8),
                  _buildCustomField(
                      controller: _emailController,
                      hint: "Enter your email or phone",
                      context: context
                  ),

                  const SizedBox(height: 16),

                  Text("Password", style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 8),
                  _buildCustomField(
                      controller: _passwordController,
                      hint: "••••••••",
                      context: context,
                      isPassword: true,
                      isVisible: _isPasswordVisible,
                      onVisibilityToggle: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      }
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                      },
                      child: const Text("Forgot password?", style: TextStyle(color: Colors.blue)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Login Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFFD1D1D)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: state is AuthLoading ? null : () {
                        final email = _emailController.text.trim();
                        final password = _passwordController.text.trim();

                        if (email.isEmpty || password.isEmpty) {
                          SnackbarUtils.showError(context, "Please fill in all fields");
                          return;
                        }

                        context.read<AuthBloc>().add(LoginRequested(email, password));
                      },
                      child: state is AuthLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Log In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const Spacer(),

                  // Signup Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                        },
                        child: const Text("Sign Up", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String hint,
    required BuildContext context,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
          onPressed: onVisibilityToggle,
        )
            : null,
      ),
    );
  }
}