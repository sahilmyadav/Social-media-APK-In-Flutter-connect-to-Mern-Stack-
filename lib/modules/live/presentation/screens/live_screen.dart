import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../../injection_container.dart';
import '../../data/repositories/live_repository.dart';
import '../bloc/live_bloc.dart';

class LiveScreen extends StatefulWidget {
  final bool isBroadcaster;
  final String? streamId; // Required if joining

  const LiveScreen({super.key, required this.isBroadcaster, this.streamId});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = LiveBloc(LiveRepository(sl()));
        if (widget.isBroadcaster) {
          bloc.add(CreateStreamEvent("My Live Stream"));
        } else if (widget.streamId != null) {
          bloc.add(JoinStreamEvent(widget.streamId!));
        }
        return bloc;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocConsumer<LiveBloc, LiveState>(
          listener: (context, state) {
            if (state is LiveEnded) Navigator.pop(context);
            if (state is LiveError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            if (state is LiveLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is LiveReady) {
              return Stack(
                children: [
                  // 1. Video Layer
                  Center(
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: state.engine,
                        canvas: const VideoCanvas(uid: 0), // 0 for local/remote auto
                      ),
                    ),
                  ),

                  // 2. Top Bar (Live Badge & Viewers)
                  Positioned(
                    top: 50,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.purple, Colors.red]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                              const SizedBox(width: 5),
                              Text("${state.stream.viewersCount}", style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => context.read<LiveBloc>().add(EndStreamEvent()),
                        ),
                      ],
                    ),
                  ),

                  // 3. Comments Area
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.white],
                          stops: [0.0, 0.3],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: 5, // Mock comments for now
                        itemBuilder: (context, index) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              "User: This is amazing! 🔥",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 4. Bottom Controls (Comment Input, Camera Switch, Hearts)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Comment...",
                                hintStyle: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (widget.isBroadcaster)
                          IconButton(
                            icon: const Icon(Icons.cameraswitch, color: Colors.white),
                            onPressed: () => context.read<LiveBloc>().add(ToggleCameraEvent()),
                          ),
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () {
                            // Emit heart animation logic here
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const Center(child: Text("Initializing...", style: TextStyle(color: Colors.white)));
          },
        ),
      ),
    );
  }
}