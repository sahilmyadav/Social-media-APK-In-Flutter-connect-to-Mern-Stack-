import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/responsive.dart';
import '../../../call/presentation/bloc/call_bloc.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../bloc/chat_bloc.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../modules/user/domain/entities/user_entity.dart';
import '../../../user/presentation/widgets/user_avatar.dart';
import '../widgets/full_screen_media.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for Location
// ... existing imports

class ChatDetailScreen extends StatefulWidget {
  final String threadId;
  final UserEntity user;
  final ChatBloc chatBloc;

  const ChatDetailScreen({
    super.key,
    required this.threadId,
    required this.user,
    required this.chatBloc,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _debounce;
  bool _isOtherUserTyping = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
        "👆 UI: ChatDetailScreen initialized for thread: ${widget.threadId}");
    widget.chatBloc.add(LoadMessages(widget.threadId));
    // Mark messages as seen when opening thread
    widget.chatBloc.repository.markMessagesSeen(widget.threadId);

    // Typing Listener
    _controller.addListener(_onTyping);

    // Listen for other user typing status
    widget.chatBloc.repository.typingStream.listen((data) {
      if (data['threadId'] == widget.threadId &&
          data['senderId'] == widget.user.id) {
        if (mounted) {
          setState(() {
            _isOtherUserTyping = data['isTyping'] ?? false;
          });
        }
      }
    });
  }

  void _onTyping() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    widget.chatBloc.repository.sendTyping(widget.threadId, widget.user.id);

    _debounce = Timer(const Duration(seconds: 2), () {
      widget.chatBloc.repository
          .sendStopTyping(widget.threadId, widget.user.id);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.chatBloc.repository.sendStopTyping(widget.threadId, widget.user.id);
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      final picker = ImagePicker();
      final XFile? file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source);

      if (!mounted) return;

      if (file != null) {
        debugPrint("👆 UI: Selected media: ${file.path}, isVideo: $isVideo");
        widget.chatBloc.add(SendMediaMessageEvent(
            widget.threadId, File(file.path), isVideo ? 'video' : 'image'));
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  Future<void> _sendLocation() async {
    try {
      final status = await Permission.location.request();

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Location Permission"),
            content: const Text(
                "Location permission is required to share your location. Please enable it in settings."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text("Settings"),
              ),
            ],
          ),
        );
        return;
      }

      if (status.isGranted) {
        final position = await Geolocator.getCurrentPosition();
        if (!mounted) return;

        // Sending location as text content for now, or could implement specific location type handling
        // in backend. Using 'location' type as per plan.
        debugPrint(
            "👆 UI: Sending location: ${position.latitude},${position.longitude}");
        widget.chatBloc.add(SendMessageEvent(
          widget.threadId,
          "${position.latitude},${position.longitude}", // lat,lng
          type: 'location',
        ));
      }
      // If status.isDenied, do nothing. User just denied the system dialog.
    } catch (e) {
      debugPrint("Error sending location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get location: $e")),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        widget.chatBloc.add(SendMediaMessageEvent(
          widget.threadId,
          File(path),
          'audio',
          duration: 0, // Calculate if possible or leave 0
        ));
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.pink),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.purple),
              title: const Text("Photo & Video"),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text("Document"),
              onTap: () => Navigator.pop(context), // Placeholder
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text("Location"),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            SizedBox(height: Responsive.h(20)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(dynamic message) {
    // message is MessageEntity but dynamic to avoid casting issues in builder if any
    final isMe = message.isMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    switch (message.type) {
      case 'image':
        content = GestureDetector(
          onTap: () {
            if (message.mediaUrl != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenMedia(
                    url: message.mediaUrl!,
                    isVideo: false,
                  ),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: message.mediaUrl != null
                ? Image.network(
                    message.mediaUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, chunks) {
                      if (chunks == null) return child;
                      return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[300],
                          child:
                              const Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey,
                        child: const Icon(Icons.error)),
                  )
                : const SizedBox(),
          ),
        );
        break;
      case 'video':
        content = GestureDetector(
          onTap: () {
            if (message.mediaUrl != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenMedia(
                    url: message.mediaUrl!,
                    isVideo: true,
                  ),
                ),
              );
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: message.thumbnailUrl != null
                    ? Image.network(
                        message.thumbnailUrl!,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 200,
                          height: 150,
                          color: Colors.black,
                          child: const Icon(Icons.error, color: Colors.white),
                        ),
                      )
                    : Container(
                        width: 200,
                        height: 150,
                        color: Colors.black, // Placeholder for thumbnail
                        child: const Center(
                            child: Icon(Icons.play_circle_outline,
                                color: Colors.white, size: 50)),
                      ),
              ),
              // Play Icon Overlay
              const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white70, size: 50)),
            ],
          ),
        );
        break;
      case 'audio':
        content = Container(
          width: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.audiotrack, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Audio Message",
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (message.duration != null)
                Text(
                  "${(message.duration! ~/ 60)}:${(message.duration! % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.black54),
                ),
            ],
          ),
        );
        break;
      case 'location':
        content = GestureDetector(
          onTap: () async {
            final coords = message.content.split(',');
            if (coords.length == 2) {
              final lat = coords[0].trim();
              final lng = coords[1].trim();
              final url = Uri.parse(
                  "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                debugPrint("Could not launch $url");
              }
            }
          },
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Current Location",
                        style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Text(
                //   message.content, // "lat,lng"
                //   style: TextStyle(
                //       color: isMe ? Colors.white70 : Colors.black54,
                //       fontSize: 12),
                // ),
                // const SizedBox(height: 4),
                // Placeholder for "View Map"
                Text(
                  "Tap to view on map",
                  style: TextStyle(
                      color: isMe ? Colors.white54 : Colors.blue,
                      fontSize: 10,
                      fontStyle: FontStyle.italic),
                )
              ],
            ),
          ),
        );
        break;
      default:
        content = Text(
          message.content,
          style: TextStyle(
            color:
                isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: Responsive.sp(14),
          ),
        );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Message',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      // Confirm Dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Delete Message"),
                          content: const Text(
                              "Are you sure you want to delete this message?"),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel")),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.chatBloc
                                    .add(DeleteMessageEvent(message.id));
                              },
                              child: const Text("Delete",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: Responsive.screenWidth * 0.75,
          ),
          margin: Responsive.padSymmetric(vertical: 2, horizontal: 4),
          padding: Responsive.padSymmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF3797F0)
                : (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(Responsive.r(18)),
              topRight: Radius.circular(Responsive.r(18)),
              bottomLeft: isMe
                  ? Radius.circular(Responsive.r(18))
                  : Radius.circular(Responsive.r(4)),
              bottomRight: isMe
                  ? Radius.circular(Responsive.r(4))
                  : Radius.circular(Responsive.r(18)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              content,
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(
                    DateTime.tryParse(message.createdAt) ?? DateTime.now()),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initiateCall(String type) {
    final callBloc = context.read<CallBloc>();
    // API expects 'audio' for voice calls, but UI might say 'voice'
    final apiType = type == 'voice' ? 'audio' : type;

    callBloc.add(StartCallEvent(widget.user.id, apiType));

    // Use CallScreen for outgoing calls to show camera preview (for video) or avatar (for audio)
    // The Bloc now emits CallActive immediately for outgoing calls
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: callBloc,
          child: const CallScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor =
        isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return BlocProvider.value(
      value: widget.chatBloc,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: StreamBuilder<Map<String, dynamic>>(
            stream: widget.chatBloc.repository.userStatusStream,
            builder: (context, snapshot) {
              bool isOnline = widget.user.isOnline;
              // String? lastSeen = widget.user.lastSeen;

              if (snapshot.hasData) {
                final data = snapshot.data!;
                if (data['userId'] == widget.user.id) {
                  isOnline = data['isOnline'] ?? false;
                  // lastSeen = data['lastSeen'];
                }
              }

              return Row(
                children: [
                  UserAvatar(
                      imageUrl: widget.user.profilePicture,
                      radius: Responsive.r(16)),
                  SizedBox(width: Responsive.w(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.username,
                          style: TextStyle(
                              fontSize: Responsive.sp(16), color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isOtherUserTyping)
                          Text(
                            "Typing...",
                            style: TextStyle(
                              fontSize: Responsive.sp(12),
                              color: const Color(0xFF3797F0),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            isOnline ? "Online" : "Offline",
                            style: TextStyle(
                              fontSize: Responsive.sp(12),
                              color: isOnline ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            // Voice Call
            IconButton(
              icon: Icon(Icons.call, size: Responsive.sp(22)),
              onPressed: () => _initiateCall('voice'),
            ),
            // Video Call
            IconButton(
              icon: Icon(Icons.videocam, size: Responsive.sp(24)),
              onPressed: () => _initiateCall('video'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Messages Area
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  if (state is ChatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ChatError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(state.message,
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: Responsive.sp(14))),
                          SizedBox(height: Responsive.h(8)),
                          ElevatedButton(
                            onPressed: () {
                              widget.chatBloc
                                  .add(LoadMessages(widget.threadId));
                            },
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is MessagesLoaded) {
                    if (state.messages.isEmpty) {
                      return Center(
                        child: Text("No messages yet. Say hi! 👋",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: Responsive.sp(16))),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding:
                          Responsive.padSymmetric(horizontal: 8, vertical: 8),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message =
                            state.messages[state.messages.length - 1 - index];
                        return _buildMessageItem(message);
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            // Input Area
            Container(
              padding: Responsive.padSymmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  top: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                ),
              ),
              child: SafeArea(
                child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      final isTextEmpty = value.text.trim().isEmpty;
                      return Row(
                        children: [
                          // Plus Button
                          IconButton(
                            icon: Icon(Icons.add,
                                color: Colors.blue, size: Responsive.sp(26)),
                            onPressed: _showAttachmentMenu,
                          ),
                          // Text Field Container
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: inputBgColor,
                                borderRadius:
                                    BorderRadius.circular(Responsive.r(24)),
                              ),
                              padding:
                                  const EdgeInsets.only(left: 12, right: 8),
                              child: TextField(
                                controller: _controller,
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: Responsive.sp(14)),
                                decoration: InputDecoration(
                                  hintText: _isRecording
                                      ? "Recording..."
                                      : "Message...",
                                  hintStyle: TextStyle(
                                      color: _isRecording
                                          ? Colors.red
                                          : Colors.grey,
                                      fontSize: Responsive.sp(14)),
                                  border: InputBorder.none,
                                  contentPadding: Responsive.padSymmetric(
                                      horizontal: 0, vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: Responsive.w(8)),

                          // Send / Mic Button
                          if (isTextEmpty)
                            GestureDetector(
                              onLongPressStart: (_) => _startRecording(),
                              onLongPressEnd: (_) => _stopRecording(),
                              child: CircleAvatar(
                                radius: Responsive.r(22),
                                backgroundColor: _isRecording
                                    ? Colors.red
                                    : const Color(0xFF3797F0),
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: Responsive.sp(20),
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                if (_controller.text.trim().isNotEmpty) {
                                  debugPrint(
                                      "👆 UI: Sending text: ${_controller.text.trim()}");
                                  widget.chatBloc.add(SendMessageEvent(
                                      widget.threadId,
                                      _controller.text.trim()));
                                  _controller.clear();
                                }
                              },
                              child: CircleAvatar(
                                radius: Responsive.r(22),
                                backgroundColor: const Color(0xFF3797F0),
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: Responsive.sp(20),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
