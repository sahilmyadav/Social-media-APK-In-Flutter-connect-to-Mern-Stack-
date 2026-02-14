import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_bloc.dart';

class StoryViewScreen extends StatefulWidget {
  // OLD CODE:
  // final StoryFeedEntity initialStory;
  // const StoryViewScreen({super.key, required this.initialStory});

  // NEW CODE:
  final List<StoryFeedEntity> storiesFeed;
  final int initialUserIndex;

  const StoryViewScreen({
    super.key,
    required this.storiesFeed,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  // int _currentIndex = 0; // Renamed to _currentStoryIndex for clarity
  int _currentStoryIndex = 0;
  int _currentUserIndex = 0;

  late List<StoryItemEntity> _stories;
  Timer? _timer;
  double _percent = 0.0;
  VideoPlayerController? _videoController;
  final _storage = const FlutterSecureStorage();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // OLD CODE:
    // _stories = widget.initialStory.stories;
    // _getCurrentUser();
    // _loadStory(0);

    // NEW CODE:
    _currentUserIndex = widget.initialUserIndex;
    _stories = widget.storiesFeed[_currentUserIndex].stories;
    _getCurrentUser();

    // Find first unseen story
    int firstUnseenIndex = _stories.indexWhere((s) => !s.hasViewed);
    if (firstUnseenIndex == -1) firstUnseenIndex = 0;

    _loadStory(firstUnseenIndex);
  }

  Future<void> _getCurrentUser() async {
    _currentUserId = await _storage.read(key: 'userId');
    setState(() {});
  }

  void _loadStory(int index) {
    // Determine stories for current user
    _stories = widget.storiesFeed[_currentUserIndex].stories;

    if (index < 0 || index >= _stories.length) return;

    _currentStoryIndex = index;
    _percent = 0.0;
    _timer?.cancel();
    _videoController?.dispose();
    _videoController = null;

    final story = _stories[_currentStoryIndex];

    // Mark as viewed
    context.read<StoryBloc>().add(ViewStoryEvent(story.id));

    if (story.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(
          Uri.parse("https://clikkme.in${story.mediaUrl}"))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
            _startTimer(story.duration);
          }
        });
    } else {
      _startTimer(story.duration);
    }
  }

  void _startTimer(int durationSeconds) {
    _timer?.cancel();
    // Default to 5s if duration is weird
    int duration = durationSeconds > 0 ? durationSeconds : 5;
    const stepMs = 50;
    final totalSteps = (duration * 1000) / stepMs;

    _timer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (!mounted) return;
      setState(() {
        _percent += 1.0 / totalSteps;
        if (_percent >= 1.0) {
          _nextStory();
        }
      });
    });
  }

  void _nextStory() {
    if (_currentStoryIndex < _stories.length - 1) {
      _loadStory(_currentStoryIndex + 1);
    } else {
      // OLD CODE:
      // Navigator.pop(context); // Close if finished

      // NEW CODE: Try next user
      if (_currentUserIndex < widget.storiesFeed.length - 1) {
        setState(() {
          _currentUserIndex++;
          // Load first story of next user
          // Optional: find first unseen? usually sequences start from 0 for new user
          // But if we want to skip seen stories for next user, we can do that.
          // For now, start from 0 for next user.
          _loadStory(0);
        });
      } else {
        // No more users
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      _loadStory(_currentStoryIndex - 1);
    } else {
      // OLD CODE:
      // // Loop or restart? For now restart
      // _loadStory(0);

      // NEW CODE: Try previous user
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          // Load last story of previous user
          _stories = widget.storiesFeed[_currentUserIndex].stories;
          _loadStory(_stories.length - 1);
        });
      } else {
        // At very beginning
        _loadStory(0);
      }
    }
  }

  void _deleteStory(String storyId) {
    context.read<StoryBloc>().add(DeleteStoryEvent(storyId));
    // Remove from local list and UI
    setState(() {
      _stories.removeAt(_currentStoryIndex);
    });
    if (_stories.isEmpty) {
      Navigator.pop(context);
    } else {
      // Load next or previous
      if (_currentStoryIndex >= _stories.length) {
        _currentStoryIndex = _stories.length - 1;
      }
      _loadStory(_currentStoryIndex);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _stories is updated in _loadStory/initState. checks safety
    if (_stories.isEmpty) return const SizedBox();

    // Ensure index safety
    if (_currentStoryIndex >= _stories.length) _currentStoryIndex = 0;

    final story = _stories[_currentStoryIndex];
    // OLD CODE:
    // final isMe = _currentUserId == widget.initialStory.user.id;

    // NEW CODE:
    final currentUserFeed = widget.storiesFeed[_currentUserIndex];
    final isMe = _currentUserId == currentUserFeed.user.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPress: () async {
          if (isMe) {
            _videoController?.pause(); // Pause video if playing
            _timer?.cancel(); // Pause timer

            final shouldDelete = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Delete Story"),
                content:
                    const Text("Are you sure you want to delete this story?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (shouldDelete == true) {
              if (mounted) _deleteStory(_stories[_currentStoryIndex].id);
            } else {
              // Resume
              if (mounted && _stories.contains(_stories[_currentStoryIndex])) {
                _videoController?.play();
                // Resume timer with original duration to maintain speed
                _startTimer(_stories[_currentStoryIndex].duration);
              }
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Content
            if (story.mediaType == 'video' &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!)),
              )
            else if (story.mediaType == 'image')
              CachedNetworkImage(
                imageUrl: "https://clikkme.in${story.mediaUrl}",
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.grey)),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.error, color: Colors.white)),
              )
            else
              const Center(
                  child: CircularProgressIndicator(color: Colors.white)),

            // 2. Caption Overlay
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Text(
                  story.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),

            // 3. Progress Bars
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Row(
                children: _stories
                    .asMap()
                    .map((i, e) {
                      return MapEntry(
                          i,
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: LinearProgressIndicator(
                                value: i < _currentStoryIndex
                                    ? 1.0
                                    : (i == _currentStoryIndex
                                        ? _percent
                                        : 0.0),
                                backgroundColor: Colors.white24,
                                valueColor:
                                    const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ));
                    })
                    .values
                    .toList(),
              ),
            ),

            // 4. User Info
            Positioned(
              top: 55,
              left: 15,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: currentUserFeed.user.profilePicture != null
                        ? CachedNetworkImageProvider(
                            "https://clikkme.in${currentUserFeed.user.profilePicture}")
                        : null,
                    child: currentUserFeed.user.profilePicture == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(currentUserFeed.user.username,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Text(
                      // Simple time display, could use timeago
                      story.createdAt.split('T').first,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

            // 5. Close Button
            Positioned(
              top: 55,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // 6. Delete / Viewers (If Me)
            if (isMe)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 5),
                        Text("${story.viewsCount}",
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        _videoController?.pause();
                        _timer?.cancel();
                        final shouldDelete = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Story"),
                            content: const Text(
                                "Are you sure you want to delete this story?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );

                        if (shouldDelete == true) {
                          if (mounted) _deleteStory(story.id);
                        } else {
                          if (mounted && _stories.contains(story)) {
                            _videoController?.play();
                            _startTimer(story.duration);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
