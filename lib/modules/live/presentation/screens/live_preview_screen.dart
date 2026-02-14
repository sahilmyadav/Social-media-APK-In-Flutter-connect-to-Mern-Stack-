import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/live_stream_entity.dart';
import '../bloc/live_bloc.dart';
import 'live_broadcast_screen.dart';

class LivePreviewScreen extends StatefulWidget {
  final LiveStreamEntity stream;

  const LivePreviewScreen({super.key, required this.stream});

  @override
  State<LivePreviewScreen> createState() => _LivePreviewScreenState();
}

class _LivePreviewScreenState extends State<LivePreviewScreen> {
  RtcEngine? _engine;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      if (LiveBloc.appId.isEmpty || LiveBloc.appId.length < 10) {
        throw Exception(
            "Invalid Agora App ID. Please update it in LiveBloc.dart");
      }
      await [Permission.camera, Permission.microphone].request();
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(appId: LiveBloc.appId));
      await _engine!.enableVideo();
      await _engine!.startPreview();

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint("Agora Init Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Camera Error: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  @override
  void dispose() {
    _engine
        ?.release(); // Release this engine instance as the Bloc will create a new one for official broadcast
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveBloc, LiveState>(
      listener: (context, state) {
        if (state is LiveBroadcasting) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LiveBroadcastScreen(
                  stream: widget.stream, engine: state.engine),
            ),
          );
        } else if (state is LiveError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              // Camera Preview
              if (_isReady)
                AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),

              // Overlay Information
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text("Preview",
                          style: TextStyle(color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),

              // Bottom Controls
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Text(widget.stream.title,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => _engine?.switchCamera(),
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white24),
                        ),
                        ElevatedButton(
                          onPressed: state is LiveLoading
                              ? null
                              : () {
                                  // Stop local preview engine release it so Bloc can take over
                                  _engine?.release();
                                  context.read<LiveBloc>().add(
                                      StartBroadcastingEvent(widget.stream));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4B6E),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          child: state is LiveLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white))
                              : const Text("Go Live",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () {}, // Mic toggle placeholder
                          icon: const Icon(Icons.mic, color: Colors.white),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white24),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
