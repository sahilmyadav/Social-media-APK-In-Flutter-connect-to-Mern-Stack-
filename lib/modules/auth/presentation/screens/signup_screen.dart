import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'otp_verification_screen.dart';
import 'login_screen.dart'; // Import Login
import '../../../../core/utils/snackbar_utils.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ... [Keep controllers and methods same as before] ...
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _dobController = TextEditingController();

  String _gender = "Male";
  bool _isPasswordVisible = false;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = "";
  Color _strengthColor = Colors.grey;

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() { _passwordStrength = 0.0; _passwordStrengthText = ""; });
      return;
    }
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$&*~]'))) score++;

    setState(() {
      _passwordStrength = score / 4;
      if (score <= 1) { _passwordStrengthText = "Weak"; _strengthColor = Colors.red; }
      else if (score <= 3) { _passwordStrengthText = "Medium"; _strengthColor = Colors.orange; }
      else { _passwordStrengthText = "Strong"; _strengthColor = Colors.green; }
    });
  }

  void _showDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1c1c1c) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    maximumDate: DateTime.now(),
                    minimumDate: DateTime(1900),
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() { _dobController.text = DateFormat('yyyy-MM-dd').format(newDate); });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    // FIX: Removed AppBar with Back Button
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          } else if (state is AuthOtpSent) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(identifier: state.identifier, isLogin: false)
            ));
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor))),
                  const Center(child: Text('Join ClickME and start sharing', style: TextStyle(color: Colors.grey, fontSize: 16))),
                  const SizedBox(height: 30),

                  _buildLabel("Full Name", textColor),
                  _buildCustomTextField(_fullNameController, "John Doe", context),

                  const SizedBox(height: 15),
                  _buildLabel("Email", textColor),
                  _buildCustomTextField(_emailController, "name@example.com", context),

                  const SizedBox(height: 15),
                  _buildLabel("Phone Number", textColor),
                  _buildCustomTextField(_phoneController, "+91 9876543210", context, isPhone: true),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Gender", textColor),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
                                border: isDark ? null : Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _gender,
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                  dropdownColor: isDark ? const Color(0xFF262626) : Colors.white,
                                  style: TextStyle(color: textColor),
                                  items: ["Male", "Female", "Other"].map((String value) {
                                    return DropdownMenuItem<String>(value: value, child: Text(value));
                                  }).toList(),
                                  onChanged: (newValue) => setState(() => _gender = newValue!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Birthday", textColor),
                            GestureDetector(
                              onTap: _showDatePicker,
                              child: AbsorbPointer(
                                child: _buildCustomTextField(_dobController, "YYYY-MM-DD", context, icon: Icons.calendar_today_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  Text("You must be at least 16 years old", style: TextStyle(color: Colors.grey[500], fontSize: 12)),

                  const SizedBox(height: 15),
                  _buildLabel("Password", textColor),
                  _buildCustomTextField(_passwordController, "••••••••", context, isPassword: true, onChanged: _checkPasswordStrength),

                  if (_passwordController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _passwordStrength,
                              backgroundColor: Colors.grey[200],
                              color: _strengthColor,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_passwordStrengthText, style: TextStyle(color: _strengthColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 15),
                  _buildLabel("Confirm Password", textColor),
                  _buildCustomTextField(_confirmPassController, "••••••••", context, isPassword: true),

                  const SizedBox(height: 30),

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
                        if (_passwordController.text != _confirmPassController.text) {
                          SnackbarUtils.showError(context, "Passwords do not match");
                          return;
                        }
                        List<String> names = _fullNameController.text.trim().split(' ');
                        String fName = names.isNotEmpty ? names.first : "";
                        String lName = names.length > 1 ? names.sublist(1).join(' ') : "";

                        context.read<AuthBloc>().add(RegisterRequested(
                          firstName: fName,
                          lastName: lName,
                          email: _emailController.text.trim(),
                          phone: _phoneController.text.trim(),
                          password: _passwordController.text,
                          gender: _gender.toLowerCase(),
                          dob: _dobController.text,
                        ));
                      },
                      child: state is AuthLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
                      GestureDetector(
                        // FIX: Use pushReplacement to switch to Login
                        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: const Text('Log In', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold)),
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

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildCustomTextField(TextEditingController controller, String hint, BuildContext context, {bool isPassword = false, bool isPhone = false, IconData? icon, Function(String)? onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      onChanged: onChanged,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: isPhone ? [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ] : [],
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: icon != null
            ? Icon(icon, color: Colors.grey, size: 20)
            : (isPassword
            ? IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        )
            : null),
      ),
    );
  }
}