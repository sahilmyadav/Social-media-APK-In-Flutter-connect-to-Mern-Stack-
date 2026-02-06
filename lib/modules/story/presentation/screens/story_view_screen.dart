import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../domain/entities/story_entity.dart';

class StoryViewScreen extends StatefulWidget {
  final StoryFeedEntity initialStory;
  const StoryViewScreen({super.key, required this.initialStory});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  int _currentIndex = 0;
  late List<StoryItemEntity> _stories;
  Timer? _timer;
  double _percent = 0.0;

  @override
  void initState() {
    super.initState();
    _stories = widget.initialStory.stories;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _percent = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _percent += 0.01;
        if (_percent >= 1.0) {
          _nextStory();
        }
      });
    });
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
        _startTimer();
      });
    } else {
      Navigator.pop(context); // Close if finished
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            // Tap Left -> Previous
            if (_currentIndex > 0) {
              setState(() {
                _currentIndex--;
                _startTimer();
              });
            }
          } else {
            // Tap Right -> Next
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Image
            CachedNetworkImage(
              imageUrl: "https://clikkme.in${story.mediaUrl}",
              fit: BoxFit.cover,
              placeholder: (_,__) => const Center(child: CircularProgressIndicator()),
            ),

            // 2. Progress Bars
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Row(
                children: _stories.asMap().map((i, e) {
                  return MapEntry(i, Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: LinearProgressIndicator(
                        value: i < _currentIndex ? 1.0 : (i == _currentIndex ? _percent : 0.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ));
                }).values.toList(),
              ),
            ),

            // 3. User Info
            Positioned(
              top: 55,
              left: 15,
              child: Row(
                children: [
                  CircleAvatar(backgroundImage: CachedNetworkImageProvider("https://clikkme.in${widget.initialStory.user.profilePicture}")),
                  const SizedBox(width: 10),
                  Text(widget.initialStory.user.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}