import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/call_bloc.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<CallBloc, CallState>(
        listener: (context, state) {
          if (state is CallEndedState) Navigator.pop(context);
        },
        builder: (context, state) {
          if (state is CallActive) {
            return Stack(
              children: [
                // 1. Remote Video (Full Screen)
                Center(
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: state.engine,
                      canvas: const VideoCanvas(uid: 0), // Remote user usually 0 or specific UID
                    ),
                  ),
                ),

                // 2. Local Video (Small PiP)
                Positioned(
                  top: 50,
                  right: 20,
                  width: 100,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: state.engine,
                        canvas: const VideoCanvas(uid: 0), // Local View
                      ),
                    ),
                  ),
                ),

                // 3. Controls
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _circleBtn(Icons.mic_off, Colors.white),
                      _circleBtn(Icons.call_end, Colors.red, onTap: () {
                        context.read<CallBloc>().add(EndCallEvent());
                      }),
                      _circleBtn(Icons.cameraswitch, Colors.white, onTap: () {
                        state.engine.switchCamera();
                      }),
                    ],
                  ),
                )
              ],
            );
          }
          return const Center(child: Text("Connecting...", style: TextStyle(color: Colors.white)));
        },
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 30,
        backgroundColor: color == Colors.white ? Colors.white24 : color,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}