import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/live_stream_entity.dart';
import '../bloc/live_bloc.dart';

class LiveViewerScreen extends StatefulWidget {
  final String streamId;

  const LiveViewerScreen({super.key, required this.streamId});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LiveBloc(sl())..add(JoinStreamEvent(widget.streamId)),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<LiveBloc, LiveState>(
          builder: (context, state) {
            if (state is LiveLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is LiveWatching) {
              return Stack(
                children: [
                  // Remote Video
                  // Remote Video - Updated to use remoteUid from state
                  if (state.remoteUid != null)
                    AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: state.engine,
                        canvas: VideoCanvas(uid: state.remoteUid),
                        connection: RtcConnection(channelId: widget.streamId),
                      ),
                    )
                  else
                    const Center(
                      child: Text(
                        "Waiting for broadcaster...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  // Old Reference (Commented out):
                  // AgoraVideoView(
                  //   controller: VideoViewController(
                  //     rtcEngine: state.engine,
                  //     canvas: const VideoCanvas(
                  //         uid:
                  //             0), // 0 for Broadcaster in single host mode usually, or specific uid
                  //   ),
                  // ),

                  // Overlay Elements
                  Positioned(
                    top: 50,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text("LIVE",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),

                  Positioned(
                    top: 50,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        context.read<LiveBloc>().add(LeaveStreamEvent());
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  // Viewer Count (Mock for UI, real if data available or stream entity updated)
                  Positioned(
                    top: 50,
                    left: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text("${state.stream.viewersCount}",
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                  // Comments & Input
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent]),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Real Comments List
                          Expanded(
                            child: ListView.builder(
                              itemCount: state.comments.length,
                              itemBuilder: (context, index) {
                                final comment = state.comments[index];
                                final user =
                                    comment['user']?['name'] ?? 'Unknown';
                                final text = comment['text'] ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(
                                          user.isNotEmpty ? user[0] : '?')),
                                  title: Text(user,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  subtitle: Text(text,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                );
                              },
                            ),
                          ),
                          TextField(
                            controller: _commentController,
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                context.read<LiveBloc>().add(SendCommentEvent(
                                    widget.streamId, value.trim()));
                                _commentController.clear();
                              }
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Say something...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none),
                              suffixIcon: IconButton(
                                icon:
                                    const Icon(Icons.send, color: Colors.white),
                                onPressed: () {
                                  final text = _commentController.text.trim();
                                  if (text.isNotEmpty) {
                                    context.read<LiveBloc>().add(
                                        SendCommentEvent(
                                            widget.streamId, text));
                                    _commentController.clear();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              );
            } else if (state is LiveError) {
              return Center(
                  child: Text(state.message,
                      style: const TextStyle(color: Colors.white)));
            } else if (state is LiveEnded) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Stream Ended",
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Exit"),
                    )
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
