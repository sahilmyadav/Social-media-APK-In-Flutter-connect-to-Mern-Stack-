import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';

class ReelPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;

  const ReelPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
  });

  @override
  State<ReelPlayerScreen> createState() => _ReelPlayerScreenState();
}

class _ReelPlayerScreenState extends State<ReelPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint("Video Error: $e");
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _error
            ? Text("Could not play video", style: GoogleFonts.inter(color: Colors.white))
            : _initialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              if (!_controller.value.isPlaying)
                const Icon(Icons.play_circle, color: Colors.white54, size: 64),
            ],
          ),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}