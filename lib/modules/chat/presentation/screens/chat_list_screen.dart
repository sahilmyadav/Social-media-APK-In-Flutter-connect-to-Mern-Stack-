import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../bloc/chat_bloc.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart'; // Import NewChatScreen
import '../../../../../injection_container.dart'; // Import Service Locator
import '../../../user/presentation/widgets/user_avatar.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Dependency Injection (sl) to provide the Bloc
    return BlocProvider(
      create: (context) => sl<ChatBloc>()
        ..add(InitChat())
        ..add(LoadThreads()),
      child: const ChatListView(),
    );
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Direct", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.penToSquare),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewChatScreen()),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ThreadsLoaded) {
            if (state.threads.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.paperPlane,
                        size: 64, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      "No chats yet",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Start a conversation by tapping the edit icon",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: state.threads.length,
              itemBuilder: (context, index) {
                final thread = state.threads[index];
                return ListTile(
                  leading: UserAvatar(
                      imageUrl: thread.participant.profilePicture, radius: 24),
                  title: Text(
                    thread.participant.username,
                    style: TextStyle(
                      fontWeight: thread.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    thread.lastMessage ?? "Start a conversation",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: thread.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: thread.unreadCount > 0
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey,
                    ),
                  ),
                  trailing: thread.unreadCount > 0
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: Colors.blue, shape: BoxShape.circle),
                        )
                      : null,
                  onTap: () {
                    // Navigate to Detail Screen
                    // IMPORTANT: Pass the existing Bloc to keep socket connection alive
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          threadId: thread.id,
                          user: thread.participant,
                          chatBloc: context.read<ChatBloc>(),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          } else if (state is ChatError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
