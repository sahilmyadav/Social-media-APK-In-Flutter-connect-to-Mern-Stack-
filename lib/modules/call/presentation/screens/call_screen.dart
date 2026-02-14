import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/responsive.dart';
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
            final isVideo = state.call.type == 'video';
            return Stack(
              children: [
                // 1. Main View
                Positioned.fill(
                  child: isVideo
                      ? (state.remoteUid != null
                          ? AgoraVideoView(
                              controller: VideoViewController.remote(
                                rtcEngine: state.engine,
                                canvas: VideoCanvas(uid: state.remoteUid),
                                connection:
                                    RtcConnection(channelId: state.channelId),
                              ),
                            )
                          : AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: state.engine,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            ))
                      : Container(
                          color: const Color(0xFF1E1E1E),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: Responsive.r(60),
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage:
                                      state.call.callerPic.isNotEmpty
                                          ? NetworkImage(state.call.callerPic)
                                          : null,
                                  child: state.call.callerPic.isEmpty
                                      ? Icon(Icons.person,
                                          size: Responsive.sp(50),
                                          color: Colors.white)
                                      : null,
                                ),
                                SizedBox(height: Responsive.h(20)),
                                Text(
                                  state.remoteUid != null
                                      ? "Connected"
                                      : "Calling...",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Responsive.sp(22),
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // 2. PiP View (Local Video) - Only for Video Calls when connected
                if (isVideo && state.remoteUid != null)
                  Positioned(
                    top: Responsive.h(50),
                    right: Responsive.w(20),
                    width: Responsive.w(100),
                    height: Responsive.h(150),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Responsive.r(10)),
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: state.engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),

                // 3. Waiting Text for Video
                if (isVideo && state.remoteUid == null)
                  Positioned(
                    bottom: Responsive.h(150),
                    left: 0,
                    right: 0,
                    child: Center(
                        child: Text("Waiting for user...",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.sp(18),
                                shadows: const [
                                  Shadow(blurRadius: 2, color: Colors.black)
                                ]))),
                  ),

                // 4. Controls
                Positioned(
                  bottom: Responsive.h(40),
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _circleBtn(Icons.mic_off, Colors.white,
                            onTap: () =>
                                state.engine.muteLocalAudioStream(true)),
                        _circleBtn(Icons.call_end, Colors.red, onTap: () {
                          context.read<CallBloc>().add(EndCallEvent());
                        }),
                        if (isVideo)
                          _circleBtn(Icons.cameraswitch, Colors.white,
                              onTap: () {
                            state.engine.switchCamera();
                          }),
                      ],
                    ),
                  ),
                )
              ],
            );
          }
          return Center(
              child: Text("Connecting...",
                  style: TextStyle(
                      color: Colors.white, fontSize: Responsive.sp(18))));
        },
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: Responsive.r(30),
        backgroundColor: color == Colors.white ? Colors.white24 : color,
        child: Icon(icon, color: Colors.white, size: Responsive.sp(28)),
      ),
    );
  }
}
