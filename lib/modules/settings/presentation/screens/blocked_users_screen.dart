import 'package:flutter/material.dart';
import '../../../../injection_container.dart';
import '../../data/repositories/settings_repository.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserEntity> _users = [];
  final _repo = SettingsRepository(sl());

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final users = await _repo.getBlockedUsers();
    setState(() => _users = users);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blocked Users")),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            title: Text(user.username),
            trailing: ElevatedButton(
              onPressed: () async {
                await _repo.unblockUser(user.id);
                _load();
              },
              child: const Text("Unblock"),
            ),
          );
        },
      ),
    );
  }
}