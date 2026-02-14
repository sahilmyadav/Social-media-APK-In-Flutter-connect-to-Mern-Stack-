import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';

import '../../domain/entities/reel_entity.dart';
import '../bloc/reels_bloc.dart';
import '../../../user/presentation/screens/profile_screen.dart';
import '../../../user/presentation/bloc/profile_bloc.dart';
import '../../../../injection_container.dart';
import '../screens/reel_comments_sheet.dart';

class ReelPlayerItem extends StatefulWidget {
  final ReelEntity reel;
  const ReelPlayerItem({super.key, required this.reel});

  @override
  State<ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<ReelPlayerItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isVisible = false; // Track visibility status
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _heartScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
        CurvedAnimation(
            parent: _heartAnimationController, curve: Curves.elasticOut));

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _heartAnimationController.reverse();
            setState(() => _showHeart = false);
          }
        });
      }
    });

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      String url = widget.reel.videoUrl;
      if (url.startsWith('/')) url = "https://clikkme.in$url";

      // FIX: getSingleFile returns a File object directly.
      // We don't need .file here.
      final videoFile = await DefaultCacheManager().getSingleFile(url);

      _controller = VideoPlayerController.file(videoFile)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _initialized = true;
              _controller!.setLooping(true);
              // CRITICAL: If the reel is already visible when init finishes, PLAY IT.
              // This ensures auto-play works if the user scrolled quickly.
              if (_isVisible) {
                _controller!.play();
              }
            });
          }
        });
    } catch (e) {
      debugPrint("Error loading reel video: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    setState(() => _showHeart = true);
    _heartAnimationController.forward(from: 0.0);
    if (!widget.reel.isLiked) {
      context.read<ReelsBloc>().add(LikeReelEvent(widget.reel.id));
    }
  }

  void _togglePlay() {
    if (_controller != null && _initialized) {
      if (_controller!.value.isPlaying)
        _controller!.pause();
      else
        _controller!.play();
    }
  }

  void _shareReel() {
    final String reelLink = "https://clikkme.in/reel/${widget.reel.id}";
    final String text =
        "Check out this reel by ${widget.reel.user.firstName}: $reelLink";
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.reel.id),
      onVisibilityChanged: (info) {
        if (!mounted) return;

        // Update visibility state
        final visible = info.visibleFraction > 0.6;
        if (_isVisible != visible) {
          _isVisible = visible;
        }

        if (!_initialized || _controller == null) return;

        if (visible) {
          if (!_controller!.value.isPlaying) _controller!.play();
        } else {
          if (_controller!.value.isPlaying) _controller!.pause();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            onDoubleTap: _handleDoubleTap,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_initialized && _controller != null)
                    // OLD CODE:
                    // Center(
                    //   child: AspectRatio(
                    //     aspectRatio: _controller!.value.aspectRatio,
                    //     child: VideoPlayer(_controller!),
                    //   ),
                    // )

                    // NEW CODE (Responsive):
                    // Auto-adjust based on video orientation.
                    // Portrait (< 1.0): Cover the screen (Immersive).
                    // Landscape (>= 1.0): Contain (Show full content, prevent pixelation/cropping).
                    // NEW CODE (Optimal Responsive):
                    // 1. Vertical Videos (< 0.8): Full Screen Cover.
                    // 2. Others (Landscape/Square): Blurred Background + Contained Video.
                    Builder(
                      builder: (context) {
                        final videoRatio = _controller!.value.aspectRatio;
                        final isVertical = videoRatio < 0.8;

                        if (isVertical) {
                          return SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.size.width,
                                height: _controller!.value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          );
                        } else {
                          // Landscape/Square: Show blurred background to fill screen
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background: Blurred Thumbnail
                              if (widget.reel.thumbnailUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: widget.reel.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const SizedBox(),
                                ),

                              // Blur Effect
                              BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),

                              // Foreground: Contained Video
                              Center(
                                child: AspectRatio(
                                  aspectRatio: videoRatio,
                                  child: VideoPlayer(_controller!),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    )
                  else
                    // Thumbnail while loading
                    CachedNetworkImage(
                      imageUrl: widget.reel.thumbnailUrl.startsWith('http')
                          ? widget.reel.thumbnailUrl
                          : "https://clikkme.in${widget.reel.thumbnailUrl}",
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.black),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.7, 1.0],
                    )),
                  ),
                ],
              ),
            ),
          ),
          if (_showHeart)
            Center(
              child: ScaleTransition(
                scale: _heartScaleAnimation,
                child:
                    const Icon(Icons.favorite, color: Colors.white, size: 100),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Like Button
                _buildCustomActionBtn(
                  child: widget.reel.isLiked
                      ? const Icon(Icons.favorite, color: Colors.red, size: 28)
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite,
                          color: Colors.white,
                          size: 28),
                  label: "${widget.reel.likesCount}",
                  onTap: () => context
                      .read<ReelsBloc>()
                      .add(LikeReelEvent(widget.reel.id)),
                ),
                const SizedBox(height: 24),

                // 2. Comment Button
                _buildCustomActionBtn(
                  child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedComment01,
                      color: Colors.white,
                      size: 28),
                  label: "${widget.reel.commentsCount}",
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) =>
                          ReelCommentsSheet(reelId: widget.reel.id),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 3. Save Button
                _buildCustomActionBtn(
                  child: widget.reel.isSaved
                      ? const Icon(Icons.bookmark, color: Colors.blue, size: 28)
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedBookmark02,
                          color: Colors.white,
                          size: 28),
                  label: "Save",
                  onTap: () => context
                      .read<ReelsBloc>()
                      .add(SaveReelEvent(widget.reel.id)),
                ),
                const SizedBox(height: 24),

                // 4. Share Button
                _buildCustomActionBtn(
                  child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSent,
                      color: Colors.white,
                      size: 28),
                  label: "Share",
                  onTap: _shareReel,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 80,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _navigateToProfile(context, widget.reel.user.id),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: widget.reel.user.profilePicture != null
                            ? CachedNetworkImageProvider(widget
                                    .reel.user.profilePicture!
                                    .startsWith('http')
                                ? widget.reel.user.profilePicture!
                                : "https://clikkme.in${widget.reel.user.profilePicture}")
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.reel.user.username,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    if (!widget.reel.isFollowing)
                      GestureDetector(
                        onTap: () => context.read<ReelsBloc>().add(
                            ToggleFollowReelUserEvent(widget.reel.user.id)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("Follow",
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (widget.reel.caption.isNotEmpty)
                  Text(widget.reel.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Original Audio • ${widget.reel.user.firstName}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
            create: (_) => sl<ProfileBloc>(),
            child: ProfileScreen(userId: userId)),
      ),
    );
  }

  Widget _buildCustomActionBtn(
      {required Widget child,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          child,
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
