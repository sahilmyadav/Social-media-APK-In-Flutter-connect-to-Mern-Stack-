import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/utils/snackbar_utils.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(title: Text("Reset Password", style: TextStyle(color: textColor)), leading: BackButton(color: textColor)),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          } else if (state is AuthPasswordResetSuccess) {
            SnackbarUtils.showSuccess(context, "Password reset successful! Please login.");
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Text("Enter the OTP sent to your email and your new password.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),

                TextField(
                  controller: _otpController,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    hintText: "OTP Code",
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _newPassController,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: const InputDecoration(
                    hintText: "New Password",
                  ),
                ),
                const SizedBox(height: 30),

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
                      context.read<AuthBloc>().add(ResetPasswordRequested(
                          email: widget.email,
                          otp: _otpController.text,
                          newPassword: _newPassController.text
                      ));
                    },
                    child: state is AuthLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Reset Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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