import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../domain/entities/post_entity.dart';
import '../bloc/feed_bloc.dart';
import '../../../user/presentation/screens/profile_screen.dart';
import '../../../user/presentation/bloc/profile_bloc.dart';
import '../../../../injection_container.dart';
import 'comments_sheet.dart';

class PostCard extends StatefulWidget {
  final PostEntity post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _heartScale = Tween<double>(begin: 0.0, end: 1.2).animate(
        CurvedAnimation(parent: _heartController, curve: Curves.elasticOut)
    );

    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if(mounted) _heartController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.post.isLiked) {
      context.read<FeedBloc>().add(LikePostEvent(widget.post.id));
    }
    _heartController.forward(from: 0.0);
  }

  void _navigateToProfile() {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProfileBloc>(),
          child: ProfileScreen(userId: widget.post.user.id),
        )
    ));
  }

  void _sharePost() {
    final url = widget.post.media.isNotEmpty && widget.post.media.first.isValid
        ? widget.post.media.first.fullUrl
        : "https://clikkme.in";
    Share.share('Check out this post by ${widget.post.user.username} on ClickME!\n$url');
  }

  void _showPostOptions(bool isDark) {
    final feedBloc = context.read<FeedBloc>();
    final textColor = isDark ? Colors.white : Colors.black;

    // Use isFollowing from UserEntity
    final bool isFollowing = widget.post.user.isFollowing ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (sheetContext) => BlocProvider.value(
        value: feedBloc,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),

              ListTile(
                leading: HugeIcon(icon: HugeIcons.strokeRoundedAlert01, color: textColor),
                title: Text("Report Post", style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportDialog(isDark, feedBloc);
                },
              ),

              ListTile(
                leading: HugeIcon(icon: isFollowing ? HugeIcons.strokeRoundedUserRemove01 : HugeIcons.strokeRoundedUserAdd01, color: textColor),
                title: Text(
                    isFollowing ? "Unfollow ${widget.post.user.username}" : "Follow ${widget.post.user.username}",
                    style: TextStyle(color: textColor)
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (isFollowing) {
                    feedBloc.add(UnfollowUserEvent(widget.post.user.id));
                  } else {
                    feedBloc.add(FollowUserFromSuggestions(widget.post.user.id));
                  }
                },
              ),

              ListTile(
                leading: HugeIcon(icon: HugeIcons.strokeRoundedLink01, color: textColor),
                title: Text("Copy Link", style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  // Implement copy logic
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(bool isDark, FeedBloc bloc) {
    showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text("Report Post", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReportItem("Spam", "spam", bloc, dialogContext),
                _buildReportItem("Inappropriate Content", "inappropriate", bloc, dialogContext),
                _buildReportItem("Violence", "violence", bloc, dialogContext),
                _buildReportItem("Hate Speech", "hate_speech", bloc, dialogContext),
              ],
            ),
          );
        }
    );
  }

  Widget _buildReportItem(String text, String reason, FeedBloc bloc, BuildContext dialogContext) {
    return ListTile(
        title: Text(text),
        onTap: () {
          bloc.add(ReportPostEvent(widget.post.id, reason, "Reported by user"));
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post reported and hidden.")));
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final validMedia = widget.post.media.where((m) => m.isValid).toList();
    // Use fullUrl getter from entity which handles fix
    final userDpUrl = widget.post.user.profilePicture ?? "";
    final fixedDpUrl = userDpUrl.startsWith("http") ? userDpUrl : "https://clikkme.in$userDpUrl";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (userDpUrl.isNotEmpty && userDpUrl.length > 5)
                      ? CachedNetworkImageProvider(fixedDpUrl)
                      : null,
                  child: (userDpUrl.isEmpty || userDpUrl.length <= 5) ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _navigateToProfile,
                    child: Text(
                      widget.post.user.username,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, size: 24, color: textColor),
                onPressed: () => _showPostOptions(isDark),
              ),
            ],
          ),
        ),

        // 2. Media Area
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (validMedia.isNotEmpty)
                SizedBox(
                  height: 400,
                  width: double.infinity,
                  child: validMedia.length > 1
                      ? CarouselSlider(
                    options: CarouselOptions(viewportFraction: 1.0, enableInfiniteScroll: false, height: 400),
                    items: validMedia.map((m) => _buildMediaItem(m)).toList(),
                  )
                      : _buildMediaItem(validMedia.first),
                )
              else
                Container(
                  height: 300, width: double.infinity, color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: Center(child: Icon(Icons.broken_image, color: isDark ? Colors.white54 : Colors.black54)),
                ),

              ScaleTransition(
                scale: _heartScale,
                child: const Icon(Icons.favorite, color: Colors.white, size: 110),
              ),
            ],
          ),
        ),

        // 3. Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  context.read<FeedBloc>().add(LikePostEvent(widget.post.id));
                },
                child: widget.post.isLiked
                    ? const Icon(Icons.favorite, color: Colors.red, size: 28)
                    : HugeIcon(icon: HugeIcons.strokeRoundedFavourite, color: textColor, size: 28),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsSheet(postId: widget.post.id),
                  );
                },
                child: HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 28, color: textColor),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _sharePost,
                child: HugeIcon(icon: HugeIcons.strokeRoundedSent, size: 28, color: textColor),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  context.read<FeedBloc>().add(SavePostEvent(widget.post.id));
                },
                child: widget.post.isSaved
                    ? const Icon(Icons.bookmark, color: Colors.blue, size: 28)
                    : HugeIcon(icon: HugeIcons.strokeRoundedBookmark02, color: textColor, size: 28),
              ),
            ],
          ),
        ),

        // 4. Details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.post.likesCount} likes',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: textColor)
              ),
              const SizedBox(height: 6),

              if (widget.post.caption.isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(color: textColor, fontSize: 14),
                    children: [
                      TextSpan(text: widget.post.user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' '),
                      TextSpan(text: widget.post.caption),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],

              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CommentsSheet(postId: widget.post.id),
                  );
                },
                child: Text('View all ${widget.post.commentsCount} comments',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 14)
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeago.format(DateTime.parse(widget.post.createdAt)),
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMediaItem(MediaEntity media) {
    if (media.type == 'video') {
      return VideoPostItem(url: media.fullUrl);
    }
    // PERFORMANCE FIX: Added memCacheHeight to resize image in memory
    return CachedNetworkImage(
      imageUrl: media.fullUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      memCacheHeight: 1200, // Optimize memory for feed scrolling
      placeholder: (context, url) => Container(color: Colors.grey[900]),
      errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))
      ),
    );
  }
}

class VideoPostItem extends StatefulWidget {
  final String url;
  const VideoPostItem({super.key, required this.url});

  @override
  State<VideoPostItem> createState() => _VideoPostItemState();
}

class _VideoPostItemState extends State<VideoPostItem> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      _hasError = true;
      return;
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setLooping(true);
        }
      }).catchError((error) {
        if(mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized || _hasError) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return Container(color: Colors.black, child: const Center(child: Icon(Icons.error_outline, color: Colors.white)));
    if (!_initialized) return Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));

    return VisibilityDetector(
      key: Key(widget.url),
      onVisibilityChanged: (info) {
        if (!_initialized || _hasError) return;

        // Auto play/pause based on visibility to save resources
        if (info.visibleFraction > 0.8) {
          if (!_isPlaying) {
            _controller.play();
            if(mounted) setState(() => _isPlaying = true);
          }
        } else {
          if (_isPlaying) {
            _controller.pause();
            if(mounted) setState(() => _isPlaying = false);
          }
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
            if (!_isPlaying)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}