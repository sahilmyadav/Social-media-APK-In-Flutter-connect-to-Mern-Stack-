import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart'; // REQUIRED: Add shimmer to pubspec.yaml

import '../../../../injection_container.dart';
import '../../data/repositories/feed_repository_impl.dart';
import '../../domain/entities/comment_entity.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FeedRepositoryImpl _repo = sl<FeedRepositoryImpl>();
  List<CommentEntity> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  CommentEntity? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  void _loadComments() {
    // 1. Load from cache first
    final cached = _repo.getCachedComments(widget.postId);
    if (cached.isNotEmpty) {
      setState(() { _comments = cached; _isLoading = false; });
    }

    // 2. Fetch fresh
    _repo.getRemoteComments(widget.postId).then((remoteComments) {
      if (mounted) {
        setState(() { _comments = remoteComments; _isLoading = false; });
      }
    }).catchError((e) {
      if (mounted && _comments.isEmpty) setState(() => _isLoading = false);
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    try {
      CommentEntity newComment;

      // CASE A: Reply
      if (_replyingTo != null) {
        newComment = await _repo.replyToComment(_replyingTo!.id, _commentController.text.trim());

        if (mounted) {
          setState(() {
            final index = _comments.indexWhere((c) => c.id == _replyingTo!.id);
            if (index != -1) {
              final parent = _comments[index];
              // Add reply to parent's list
              final updatedReplies = List<CommentEntity>.from(parent.replies)..add(newComment);

              _comments[index] = parent.copyWith(
                  replies: updatedReplies,
                  repliesCount: parent.repliesCount + 1
              );
            }
            _replyingTo = null;
            _commentController.clear();
            _isPosting = false;
          });
          _focusNode.unfocus();
        }
      }
      // CASE B: Normal Comment
      else {
        newComment = await _repo.addComment(widget.postId, _commentController.text.trim());
        if (mounted) {
          setState(() {
            _comments.insert(0, newComment);
            _commentController.clear();
            _isPosting = false;
          });
          _focusNode.unfocus();
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post")));
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
      debugPrint("Error fetching replies: $e");
    }
  }

  void _initiateReply(CommentEntity comment) {
    setState(() => _replyingTo = comment);
    _focusNode.requestFocus();
    _commentController.text = "@${comment.user.username} ";
  }

  void _toggleLike(int index) {
    final comment = _comments[index];
    final isLiked = comment.isLiked;
    setState(() {
      _comments[index] = comment.copyWith(
        isLiked: !isLiked,
        likesCount: isLiked ? comment.likesCount - 1 : comment.likesCount + 1,
      );
    });
    isLiked ? _repo.unlikeComment(comment.id) : _repo.likeComment(comment.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
              Text("Comments", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
              const SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey[800]),

              // List Body
              Expanded(
                child: _isLoading && _comments.isEmpty
                    ? _buildSkeletonList(isDark) // RESTORED SKELETON
                    : _comments.isEmpty
                    ? Center(child: Text("No comments yet.", style: GoogleFonts.inter(color: Colors.grey)))
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    return _buildCommentItem(_comments[index], index, textColor, isDark);
                  },
                ),
              ),

              // Reply Context
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: Row(
                    children: [
                      Text("Replying to ${_replyingTo!.user.username}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const Spacer(),
                      GestureDetector(onTap: () => setState(() => _replyingTo = null), child: Icon(Icons.close, size: 16, color: Colors.grey[600]))
                    ],
                  ),
                ),

              // Input Field
              _buildInputField(isDark, textColor),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGETS ---

  Widget _buildCommentItem(CommentEntity comment, int index, Color textColor, bool isDark) {
    String avatarUrl = comment.user.profilePicture ?? "";
    if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) avatarUrl = "https://clikkme.in$avatarUrl";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: (avatarUrl.isNotEmpty && avatarUrl.length > 5) ? CachedNetworkImageProvider(avatarUrl) : null,
            radius: 18,
            backgroundColor: Colors.grey[800],
            child: (avatarUrl.isEmpty || avatarUrl.length <= 5) ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: TextSpan(style: GoogleFonts.inter(color: textColor, fontSize: 13), children: [
                  TextSpan(text: "${comment.user.username} ", style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: comment.text),
                ])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(timeago.format(DateTime.parse(comment.createdAt), locale: 'en_short'), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(width: 16),
                    Text("${comment.likesCount} likes", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: () => _initiateReply(comment), child: Text("Reply", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600))),
                  ],
                ),

                // Nested Replies
                if (comment.repliesCount > 0) ...[
                  const SizedBox(height: 8),
                  if (comment.replies.isNotEmpty)
                    ...comment.replies.map((reply) => _buildReplyItem(reply, textColor)).toList(),

                  if (comment.replies.isEmpty)
                    GestureDetector(
                      onTap: () => _fetchReplies(index),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            Container(width: 30, height: 1, color: Colors.grey[600]),
                            const SizedBox(width: 10),
                            Text("View ${comment.repliesCount} replies", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ]
              ],
            ),
          ),
          GestureDetector(onTap: () => _toggleLike(index), child: comment.isLiked ? const Icon(Icons.favorite, color: Colors.red, size: 16) : const Icon(Icons.favorite_border, color: Colors.grey, size: 16)),
        ],
      ),
    );
  }

  Widget _buildReplyItem(CommentEntity reply, Color textColor) {
    String avatarUrl = reply.user.profilePicture ?? "";
    if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) avatarUrl = "https://clikkme.in$avatarUrl";

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: (avatarUrl.length > 5) ? CachedNetworkImageProvider(avatarUrl) : null,
            radius: 12,
            backgroundColor: Colors.grey[800],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(text: TextSpan(style: GoogleFonts.inter(color: textColor, fontSize: 12), children: [
              TextSpan(text: "${reply.user.username} ", style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: reply.text),
            ])),
          ),
        ],
      ),
    );
  }

  // --- SKELETON LOADER ---
  Widget _buildSkeletonList(bool isDark) {
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.only(top: 10),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(bool isDark, Color textColor) {
    // FIX: Overflow error handled
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
            hintText: _replyingTo != null ? "Reply to ${_replyingTo!.user.username}..." : "Add a comment...",
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            filled: true,
            fillColor: isDark ? const Color(0xFF262626) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        )),
        const SizedBox(width: 12),
        _isPosting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : GestureDetector(onTap: _postComment, child: Text("Post", style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}