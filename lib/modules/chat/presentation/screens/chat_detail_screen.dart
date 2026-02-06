import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../call/presentation/bloc/call_bloc.dart';
import '../../../call/presentation/screens/incoming_call_screen.dart';
import '../bloc/chat_bloc.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';
import '../../../user/presentation/widgets/user_avatar.dart';

class ChatDetailScreen extends StatefulWidget {
  final String threadId;
  final UserEntity user;
  final ChatBloc chatBloc;

  const ChatDetailScreen({super.key, required this.threadId, required this.user, required this.chatBloc});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.chatBloc.add(LoadMessages(widget.threadId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.chatBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              UserAvatar(imageUrl: widget.user.profilePicture, radius: 16),
              const SizedBox(width: 10),
              Text(widget.user.username, style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            // ADDED: Audio Call Logic
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                final callBloc = context.read<CallBloc>();
                callBloc.add(StartCallEvent(widget.user.id, 'voice')); // 'voice' call
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(
                      callerName: widget.user.username,
                      callerPic: widget.user.profilePicture ?? '',
                      isIncoming: false,
                    ),
                  ),
                );
              },
            ),
            // Video Call Logic
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () {
                final callBloc = context.read<CallBloc>();
                callBloc.add(StartCallEvent(widget.user.id, 'video')); // 'video' call
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(
                      callerName: widget.user.username,
                      callerPic: widget.user.profilePicture ?? '',
                      isIncoming: false,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is MessagesLoaded) {
                    return ListView.builder(
                      reverse: true,
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[state.messages.length - 1 - index];
                        final isMe = message.isMe;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF3797F0) : Colors.grey[800],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              message.content,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          widget.chatBloc.add(SendMessageEvent(widget.threadId, _controller.text));
                          _controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}