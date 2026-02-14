import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/utils/responsive.dart';
import '../bloc/chat_bloc.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';
import '../../../user/presentation/widgets/user_avatar.dart';

/// Uses the global [ChatBloc] provided in main.dart's MultiBlocProvider.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Load threads using the global ChatBloc (no local BlocProvider needed)
    context.read<ChatBloc>().add(LoadThreads());
    return const ChatListView();
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text("Direct",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: Responsive.sp(18),
                color: textColor)),
        actions: [
          IconButton(
            icon: Icon(FontAwesomeIcons.penToSquare, size: Responsive.sp(20)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewChatScreen()),
              );
              // Reload threads when returning from NewChatScreen
              if (context.mounted) {
                context.read<ChatBloc>().add(LoadThreads());
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ThreadsLoaded) {
            if (state.threads.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ChatBloc>().add(LoadThreads());
              },
              child: ListView.builder(
                itemCount: state.threads.length,
                itemBuilder: (context, index) {
                  final thread = state.threads[index];
                  return Dismissible(
                    key: Key(thread.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: Responsive.w(20)),
                      child: Icon(Icons.delete,
                          color: Colors.white, size: Responsive.sp(24)),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context),
                    onDismissed: (_) {
                      // TODO: Call deleteThread API when confirmed
                    },
                    child: ListTile(
                      contentPadding:
                          Responsive.padSymmetric(horizontal: 16, vertical: 4),
                      leading: UserAvatar(
                          imageUrl: thread.participant.profilePicture,
                          radius: Responsive.r(24)),
                      title: Text(
                        thread.participant.username,
                        style: TextStyle(
                          fontWeight: thread.unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: Responsive.sp(15),
                          color: textColor,
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
                          fontSize: Responsive.sp(13),
                          color:
                              thread.unreadCount > 0 ? textColor : Colors.grey,
                        ),
                      ),
                      trailing: thread.unreadCount > 0
                          ? Container(
                              width: Responsive.w(10),
                              height: Responsive.w(10),
                              decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle),
                            )
                          : null,
                      onTap: () async {
                        final chatBloc = context.read<ChatBloc>();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              threadId: thread.id,
                              user: thread.participant,
                              chatBloc: chatBloc,
                            ),
                          ),
                        );
                        // Reload threads when returning
                        if (context.mounted) {
                          chatBloc.add(LoadThreads());
                        }
                      },
                    ),
                  );
                },
              ),
            );
          } else if (state is ChatError) {
            return Center(
                child: Text(state.message,
                    style: TextStyle(
                        color: Colors.red, fontSize: Responsive.sp(14))));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.paperPlane,
              size: Responsive.sp(64),
              color: Colors.grey.withValues(alpha: 0.5)),
          SizedBox(height: Responsive.h(16)),
          Text(
            "No chats yet",
            style: TextStyle(
                fontSize: Responsive.sp(18),
                fontWeight: FontWeight.bold,
                color: Colors.grey),
          ),
          SizedBox(height: Responsive.h(8)),
          Text(
            "Start a conversation by tapping the edit icon",
            style: TextStyle(fontSize: Responsive.sp(14), color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat"),
        content: const Text("Are you sure you want to delete this chat?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
