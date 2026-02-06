import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'complete_profile_screen.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import '../../../../presentation/main_screen.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/utils/snackbar_utils.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String identifier;
  final bool isLogin;

  const OtpVerificationScreen({super.key, required this.identifier, required this.isLogin});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() { _start = 60; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() { _canResend = true; timer.cancel(); });
      } else {
        setState(() { _start--; });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otpCode => _controllers.map((e) => e.text).join();

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      // FIX: Removed AppBar to remove back arrow entirely. Using SafeArea instead.
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          } else if (state is AuthAuthenticated) {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (route) => false);
          } else if (state is AuthProfileIncomplete) {
            Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => CompleteProfileScreen(suggestedUsername: state.suggestedUsername)
            ));
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE1306C), Color(0xFFF77737)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.lock_outline, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text("Verify Your Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                    const SizedBox(height: 10),
                    Text("Enter the 6-digit code sent to", style: TextStyle(color: Colors.grey[600])),
                    Text(widget.identifier, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),

                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 45,
                          height: 55,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262626) : Colors.white,
                            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RawKeyboardListener(
                            focusNode: FocusNode(),
                            onKey: (event) {
                              if (event is RawKeyDownEvent) {
                                if (event.logicalKey == LogicalKeyboardKey.backspace) {
                                  if (_controllers[index].text.isEmpty && index > 0) {
                                    FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                                  }
                                }
                              }
                            },
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: "",
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) => _onChanged(value, index),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    if (_canResend)
                      GestureDetector(
                        onTap: () {
                          context.read<AuthBloc>().add(ResendOtpRequested(widget.identifier));
                          _startTimer();
                          SnackbarUtils.showSuccess(context, "OTP Resent!");
                        },
                        child: const Text("Resend OTP", style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold)),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Resend OTP in ", style: TextStyle(color: Colors.grey[600])),
                          Text("00:${_start.toString().padLeft(2, '0')}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE0AAFF), Color(0xFFFF9E00)],
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: state is AuthLoading ? null : () {
                            // FIX: Passing isLogin so the Bloc knows which API to call
                            context.read<AuthBloc>().add(VerifyOtpRequested(widget.identifier, _otpCode, isLogin: widget.isLogin));
                          },
                          child: state is AuthLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Verify OTP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        // FIX: Clean navigation back to the correct screen
                        if (widget.isLogin) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        } else {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                        }
                      },
                      child: Text(
                        widget.isLogin ? "← Back to Login" : "← Back to Sign Up",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}