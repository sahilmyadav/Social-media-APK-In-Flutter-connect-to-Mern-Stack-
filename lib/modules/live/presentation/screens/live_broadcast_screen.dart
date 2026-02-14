import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../domain/entities/live_stream_entity.dart';
import '../bloc/live_bloc.dart';
import 'live_feed_screen.dart';

class LiveBroadcastScreen extends StatefulWidget {
  final LiveStreamEntity stream;
  final RtcEngine engine;

  const LiveBroadcastScreen(
      {super.key, required this.stream, required this.engine});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  final TextEditingController _commentController = TextEditingController();
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = Duration(seconds: _elapsed.inSeconds + 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _confirmEndStream() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
            child: Icon(Icons.cancel_outlined, color: Colors.red, size: 40)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("End Live Stream?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "Are you sure you want to end this live stream? This action cannot be undone.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Keep Streaming",
                      style: TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<LiveBloc>().add(EndStreamEvent());
                  },
                  child: const Text("End Stream",
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveBloc, LiveState>(
      listener: (context, state) {
        if (state is LiveEnded) {
          // Navigate back to Feed or Home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LiveFeedScreen()),
            (route) => route.isFirst,
          );
        }
      },
      builder: (context, state) {
        return WillPopScope(
          onWillPop: () async {
            _confirmEndStream();
            return false;
          },
          child: Scaffold(
            body: Stack(
              children: [
                // Broadcaster Video (Local)
                AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: widget.engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),

                // Top Bar
                Positioned(
                  top: 50,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text("LIVE",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      // Timer placeholder
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(_formatDuration(_elapsed),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                      const Spacer(),
                      // Viewer Count
                      Container(
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
                            Text(
                                "${state is LiveBroadcasting ? state.stream.viewersCount : 0}",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _confirmEndStream,
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black26),
                      ),
                    ],
                  ),
                ),

                // Bottom Area (Comments, Controls)
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
                      children: [
                        // Real Comments Area
                        if (state is LiveBroadcasting)
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              reverse: true,
                              itemCount: state.comments.length,
                              itemBuilder: (context, index) {
                                final comment = state.comments[index];
                                final user =
                                    comment['user']?['name'] ?? 'Unknown';
                                final text = comment['text'] ?? '';
                                return _buildComment(user, text);
                              },
                            ),
                          ),

                        // Controls
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Say something...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white70),
                                  filled: true,
                                  fillColor: Colors.white12,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: () {
                                final text = _commentController.text.trim();
                                if (text.isNotEmpty) {
                                  context.read<LiveBloc>().add(
                                      SendCommentEvent(widget.stream.id, text));
                                  _commentController.clear();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cameraswitch,
                                  color: Colors.white),
                              onPressed: () => context
                                  .read<LiveBloc>()
                                  .add(ToggleCameraEvent()),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComment(String user, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: Colors.grey, radius: 12, child: Text(user[0])),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(text,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }
}
