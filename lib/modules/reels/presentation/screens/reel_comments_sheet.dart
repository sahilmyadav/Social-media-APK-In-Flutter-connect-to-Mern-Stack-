import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';

import '../../../../core/local_storage/hive_helper.dart';
import '../../../../injection_container.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../data/repositories/reels_repository.dart';

class ReelCommentsSheet extends StatefulWidget {
  final String reelId;
  const ReelCommentsSheet({super.key, required this.reelId});

  @override
  State<ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<ReelCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final ReelsRepository _repo = sl<ReelsRepository>();

  List<CommentEntity> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  CommentEntity? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    // 1. Load Cache First (Instant UI)
    final cachedData = HiveHelper.getCachedComments(widget.reelId);
    if (cachedData.isNotEmpty) {
      if (mounted) {
        setState(() {
          // Convert cached Maps back to CommentEntities using your updated fromJson
          _comments = cachedData.map((e) => CommentEntity.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    }

    // 2. Fetch Fresh Data from API
    try {
      final remoteComments = await _repo.getComments(widget.reelId);
      if (mounted) {
        setState(() {
          _comments = remoteComments;
          _isLoading = false;
        });

        // 3. Update Cache
        // Convert entities back to JSON maps for storage
        // Note: Assuming your Entity doesn't have toJson, we store the raw API response in Repo usually.
        // But if you cache the Repo result, we can map entities to a simplified Map or rely on Repo caching.
        // For now, if HiveHelper expects List<dynamic>, we pass the mapped objects.
        // If your CommentEntity doesn't have toJson, this part relies on the Repo to handle the raw data caching.
        // Based on HiveHelper, it takes List. We will save the fetched list if possible.
        // Ideally, the Repo handles caching the raw JSON. If doing it here:
        // HiveHelper.cacheComments(widget.reelId, remoteComments.map((e) => ...).toList());
      }
    } catch (e) {
      if (mounted && _comments.isEmpty) {
        setState(() => _isLoading = false);
      }
      debugPrint("Error loading comments: $e");
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    _focusNode.unfocus();

    try {
      CommentEntity newComment;
      if (_replyingTo != null) {
        // Handle Reply
        final reply = await _repo.replyToComment(_replyingTo!.id, text);

        if (mounted) {
          setState(() {
            // Find parent and add reply to it for UI update
            final index = _comments.indexWhere((c) => c.id == _replyingTo!.id);
            if (index != -1) {
              final parent = _comments[index];
              final updatedReplies = List<CommentEntity>.from(parent.replies)..add(reply);
              _comments[index] = parent.copyWith(
                  replies: updatedReplies,
                  repliesCount: parent.repliesCount + 1
              );
            } else {
              // Fallback if parent not found (rare), just add to top
              _comments.insert(0, reply);
            }
            _replyingTo = null;
          });
        }
      } else {
        // Handle New Comment
        newComment = await _repo.addComment(widget.reelId, text);
        if (mounted) {
          setState(() {
            _comments.insert(0, newComment);
          });
        }
      }

      if (mounted) {
        _commentController.clear();
        setState(() => _isPosting = false);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    final comment = _comments[index];
    final bool wasLiked = comment.isLiked;
    final int oldLikes = comment.likesCount;

    // Optimistic Update
    final newLikes = wasLiked ? (oldLikes - 1) : (oldLikes + 1);
    final updatedComment = comment.copyWith(
      isLiked: !wasLiked,
      likesCount: newLikes < 0 ? 0 : newLikes,
    );

    setState(() {
      _comments[index] = updatedComment;
    });

    try {
      await _repo.toggleCommentLike(comment.id, wasLiked);
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _comments[index] = comment;
        });
      }
    }
  }

  void _fetchReplies(int index) async {
    final comment = _comments[index];
    try {
      final replies = await _repo.getCommentReplies(comment.id);
      if (mounted) {
        setState(() {
          _comments[index] = comment.copyWith(replies: replies);
        });
      }
    } catch (e) {
      debugPrint("Reply fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2)
              ),
            ),
          ),

          Text("Comments", style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          Divider(color: Colors.grey.withOpacity(0.3)),

          Expanded(
            child: _isLoading && _comments.isEmpty
                ? _buildShimmerList(isDark)
                : _comments.isEmpty
                ? Center(child: Text("No comments yet", style: GoogleFonts.inter(color: Colors.grey)))
                : ListView.builder(
              itemCount: _comments.length,
              padding: const EdgeInsets.only(bottom: 20),
              itemBuilder: (context, index) => _buildCommentItem(_comments[index], index, textColor, isDark),
            ),
          ),

          // Reply Indicator
          if (_replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: Row(
                children: [
                  Text("Replying to ${_replyingTo!.user.username}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  )
                ],
              ),
            ),

          // Input Field
          _buildInputField(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 18, backgroundColor: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 10, color: Colors.white),
                      const SizedBox(height: 6),
                      Container(width: double.infinity, height: 10, color: Colors.white),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(CommentEntity comment, int index, Color textColor, bool isDark) {
    // Ensure profile picture is valid using your Entity's logic
    final avatarUrl = comment.user.profilePicture;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[800],
                backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatarUrl!) : null,
                child: !hasAvatar ? const Icon(Icons.person, color: Colors.grey, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(color: textColor, fontSize: 13),
                        children: [
                          TextSpan(text: "${comment.user.username}  ", style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: comment.text), // Uses 'text' field from your Entity
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                            timeago.format(DateTime.tryParse(comment.createdAt) ?? DateTime.now(), locale: 'en_short'),
                            style: TextStyle(color: Colors.grey[500], fontSize: 11)
                        ),
                        const SizedBox(width: 16),
                        if (comment.likesCount > 0) ...[
                          Text("${comment.likesCount} likes", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          const SizedBox(width: 16),
                        ],
                        GestureDetector(
                          onTap: () {
                            setState(() => _replyingTo = comment);
                            _focusNode.requestFocus();
                          },
                          child: Text("Reply", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    // View Replies Button
                    if (comment.repliesCount > 0 && comment.replies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () => _fetchReplies(index),
                          child: Text(
                            "View ${comment.repliesCount} more replies",
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Like Button
              GestureDetector(
                onTap: () => _toggleLike(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    comment.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: comment.isLiked ? Colors.red : Colors.grey,
                  ),
                ),
              )
            ],
          ),

          // Replies List
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48.0, top: 8),
              child: Column(
                children: comment.replies.map((r) => _buildReplyItem(r, textColor)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommentEntity reply, Color textColor) {
    final avatarUrl = reply.user.profilePicture;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.grey[800],
            backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatarUrl!) : null,
            child: !hasAvatar ? const Icon(Icons.person, color: Colors.grey, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: textColor, fontSize: 12),
                children: [
                  TextSpan(text: "${reply.user.username} ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: reply.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(bool isDark, Color textColor) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomInset > 0 ? bottomInset + 8 : 24
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _commentController,
          focusNode: _focusNode,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: _replyingTo != null ? "Replying to ${_replyingTo!.user.username}..." : "Add a comment...",
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            filled: true,
            fillColor: isDark ? const Color(0xFF262626) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            isDense: true,
          ),
        )),
        const SizedBox(width: 12),
        _isPosting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : GestureDetector(
          onTap: _postComment,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Text(
                "Post",
                style: GoogleFonts.inter(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15)
            ),
          ),
        ),
      ]),
    );
  }
}