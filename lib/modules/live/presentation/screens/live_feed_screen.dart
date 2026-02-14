import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../bloc/live_bloc.dart';
import 'live_setup_screen.dart';
import 'live_viewer_screen.dart';

class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger fetch when screen initializes
    context.read<LiveBloc>().add(FetchAllStreamsEvent());
  }

  @override
  Widget build(BuildContext context) {
    // Removed local BlocProvider to use the global one in main.dart
    return Scaffold(
      appBar: AppBar(
        title: Text("Live",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Colors.red)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LiveSetupScreen()));
              },
              icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedVideo01,
                  size: 18,
                  color: Colors.white),
              label:
                  const Text("Go Live", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar Placeholder
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search live streams...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<LiveBloc, LiveState>(
              builder: (context, state) {
                if (state is LiveLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is LiveFeedLoaded) {
                  if (state.streams.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedWifi01,
                                size: 40,
                                color: Colors.red),
                          ),
                          const SizedBox(height: 20),
                          Text("No Live Streams",
                              style: GoogleFonts.inter(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "No one is currently live. Be the first to start streaming and connect with your audience!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LiveSetupScreen()));
                            },
                            icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedStar,
                                color: Colors.white),
                            label: const Text("Start Your Live Stream",
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                  0xFFD926B6), // Purple-ish pink from screenshot
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          )
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: state.streams.length,
                    itemBuilder: (context, index) {
                      final stream = state.streams[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      LiveViewerScreen(streamId: stream.id)));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image:
                                  CachedNetworkImageProvider(stream.thumbnail),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("LIVE",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Positioned(
                                  top: 8,
                                  left: 45,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.visibility,
                                            color: Colors.white, size: 10),
                                        const SizedBox(width: 4),
                                        Text("${stream.viewersCount}",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  )),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent
                                        ]),
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12)),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(stream.title,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(stream.user?.username ?? "User",
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
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
                } else if (state is LiveError) {
                  return Center(child: Text(state.message));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
