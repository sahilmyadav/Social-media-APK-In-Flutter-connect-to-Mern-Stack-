import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../presentation/main_screen.dart'; // To reset nav
import '../../../../modules/auth/presentation/screens/login_screen.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../injection_container.dart';
import 'blocked_users_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SettingsRepository(sl());

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("Account", style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Privacy"),
            trailing: Switch(value: false, onChanged: (val) {
              repo.updatePrivacy(isPrivate: val);
            }), // Simplified for MVP
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("Security"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text("Blocked Accounts"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await repo.logout();
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false
              );
            },
          ),
        ],
      ),
    );
  }
}