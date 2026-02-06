import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../bloc/call_bloc.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final String callerName;
  final String callerPic;
  final bool isIncoming;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerPic,
    required this.isIncoming,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Insta theme
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundImage: CachedNetworkImageProvider("https://clikkme.in$callerPic"),
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              isIncoming ? "Incoming Video Call..." : "Calling...",
              style: const TextStyle(color: Colors.grey, fontSize: 18),
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
                  _actionBtn("Accept", Icons.videocam, Colors.green, () {
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
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 35,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}