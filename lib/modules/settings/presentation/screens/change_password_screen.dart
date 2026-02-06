import 'package:flutter/material.dart';
import '../../../../injection_container.dart';
import '../../data/repositories/settings_repository.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: oldPass, decoration: const InputDecoration(labelText: "Current Password")),
            const SizedBox(height: 10),
            TextField(controller: newPass, decoration: const InputDecoration(labelText: "New Password")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SettingsRepository(sl()).changePassword(oldPass.text, newPass.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Changed")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed")));
                }
              },
              child: const Text("Update"),
            )
          ],
        ),
      ),
    );
  }
}