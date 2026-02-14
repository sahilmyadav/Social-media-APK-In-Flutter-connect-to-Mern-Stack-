import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/responsive.dart';
import '../bloc/call_bloc.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerPic;
  final bool isIncoming;
  final String callType; // 'voice' or 'video'

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerPic,
    required this.isIncoming,
    this.callType = 'video',
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = callType == 'video';
    final callLabel = isIncoming
        ? (isVideo ? "Incoming Video Call..." : "Incoming Voice Call...")
        : "Calling...";

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Caller Avatar
            CircleAvatar(
              radius: Responsive.r(60),
              backgroundColor: Colors.grey[800],
              backgroundImage: (callerPic.isNotEmpty)
                  ? CachedNetworkImageProvider("https://clikkme.in$callerPic")
                  : null,
              child: callerPic.isEmpty
                  ? Icon(Icons.person,
                      size: Responsive.sp(50), color: Colors.grey[500])
                  : null,
            ),
            SizedBox(height: Responsive.h(20)),
            Text(
              callerName,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.sp(28),
                  fontWeight: FontWeight.bold),
            ),
            Text(
              callLabel,
              style: TextStyle(color: Colors.grey, fontSize: Responsive.sp(18)),
            ),
            const Spacer(),

            // Actions
            if (isIncoming)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionBtn("Decline", Icons.call_end, Colors.red, () {
                    context.read<CallBloc>().add(EndCallEvent());
                    Navigator.pop(context);
                  }),
                  _actionBtn("Accept", isVideo ? Icons.videocam : Icons.call,
                      Colors.green, () {
                    context.read<CallBloc>().add(AcceptCallEvent());
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CallScreen()),
                    );
                  }),
                ],
              )
            else
              _actionBtn("Cancel", Icons.close, Colors.red, () {
                context.read<CallBloc>().add(EndCallEvent());
                Navigator.pop(context);
              }),
            SizedBox(height: Responsive.h(50)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: Responsive.r(35),
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: Responsive.sp(32)),
          ),
        ),
        SizedBox(height: Responsive.h(10)),
        Text(label,
            style: TextStyle(color: Colors.white, fontSize: Responsive.sp(14))),
      ],
    );
  }
}
