import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class CommentEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String text;
  final int likesCount;
  final bool isLiked;
  final int repliesCount;
  final String? parentId;
  final String createdAt;
  final List<CommentEntity> replies;

  const CommentEntity({
    required this.id,
    required this.user,
    required this.text,
    this.likesCount = 0,
    this.isLiked = false,
    this.repliesCount = 0,
    this.parentId,
    required this.createdAt,
    this.replies = const [],
  });

  factory CommentEntity.fromJson(Map<dynamic, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json as Map);

    // 1. Handle User Mapping (Fix for missing username)
    Map<String, dynamic> userData = {};

    // API returns user details inside 'user_id' for comments
    if (safeJson['user_id'] != null && safeJson['user_id'] is Map) {
      userData = Map<String, dynamic>.from(safeJson['user_id']);
    } else if (safeJson['user'] != null && safeJson['user'] is Map) {
      userData = Map<String, dynamic>.from(safeJson['user']);
    }

    // 2. Fix Username: If username is null, combine firstName + lastName
    if (userData['username'] == null || userData['username'].toString().isEmpty) {
      String first = userData['firstName'] ?? '';
      String last = userData['lastName'] ?? '';
      String generatedName = "$first $last".trim();
      userData['username'] = generatedName.isNotEmpty ? generatedName : 'Unknown User';
    }

    // 3. Fix Profile Picture URLs
    String? rawDp;
    if (userData['profilePicture'] != null) rawDp = userData['profilePicture'];
    else if (userData['avatar'] != null) rawDp = userData['avatar'];
    else if (userData['profileImage'] != null) rawDp = userData['profileImage'];

    if (rawDp != null) {
      String pp = rawDp.toString();
      if (pp.startsWith('/')) pp = "https://clikkme.in$pp";
      userData['profilePicture'] = pp;
    }

    // 4. Content Mapping
    String content = safeJson['content']?.toString() ?? safeJson['text']?.toString() ?? '';

    return CommentEntity(
      id: safeJson['_id']?.toString() ?? '',
      user: UserEntity.fromJson(userData),
      text: content,
      likesCount: int.tryParse(safeJson['likes_count'].toString()) ?? 0,
      isLiked: safeJson['isLiked'] == true,
      repliesCount: int.tryParse(safeJson['replies_count'].toString()) ?? 0,
      parentId: safeJson['reply_to_comment_id']?.toString() ?? safeJson['parent_id']?.toString(),
      createdAt: safeJson['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      replies: safeJson['replies'] != null
          ? (safeJson['replies'] as List).map((e) => CommentEntity.fromJson(e)).toList()
          : [],
    );
  }

  CommentEntity copyWith({
    bool? isLiked,
    int? likesCount,
    int? repliesCount,
    List<CommentEntity>? replies,
    String? text,
  }) {
    return CommentEntity(
      id: id,
      user: user,
      text: text ?? this.text,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      repliesCount: repliesCount ?? this.repliesCount,
      parentId: parentId,
      createdAt: createdAt,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [id, text, isLiked, likesCount, repliesCount, replies];
}