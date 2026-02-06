import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
// import 'reset_password_screen.dart'; // Not needed anymore based on requirements
import '../../../../core/utils/snackbar_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(leading: BackButton(color: textColor)),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          } else if (state is AuthPasswordResetEmailSent) {
            // FIX 3: Just show success message, do not navigate to reset screen
            SnackbarUtils.showSuccess(context, "Link sent to ${state.email}");

            // Optional: Pop back to login after a delay or immediately
            // Navigator.pop(context);

            /* // Commented out as requested
            Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(email: state.email)
            ));
            */
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lock_reset, size: 80, color: textColor),
                const SizedBox(height: 20),
                Text("Trouble Logging In?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 10),
                const Text("Enter your email and we'll send you a link to get back into your account.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: _emailController,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    hintText: "Email",
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF833AB4), Color(0xFFC13584), Color(0xFFE1306C), Color(0xFFFD1D1D)],
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
                      context.read<AuthBloc>().add(ForgotPasswordRequested(_emailController.text));
                    },
                    child: state is AuthLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Send Login Link", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}