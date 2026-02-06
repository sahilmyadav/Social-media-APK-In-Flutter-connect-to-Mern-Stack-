import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class ReelEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;

  const ReelEntity({
    required this.id,
    required this.user,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    this.isSaved = false,
    this.isFollowing = false,
  });

  factory ReelEntity.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse booleans from various API formats
    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val.toLowerCase() == 'true';
      return false;
    }

    return ReelEntity(
      id: json['_id']?.toString() ?? '',
      user: UserEntity.fromJson(json['user_id'] ?? {}),
      videoUrl: json['video_url'] ?? json['media']?['url'] ?? '',
      thumbnailUrl: json['thumbnail'] ?? json['media']?['thumbnail'] ?? '',
      caption: json['caption'] ?? '',
      likesCount: int.tryParse(json['likes_count'].toString()) ?? 0,
      commentsCount: int.tryParse(json['comments_count'].toString()) ?? 0,
      isLiked: parseBool(json['isLiked']) || parseBool(json['is_liked']),
      isSaved: parseBool(json['isSaved']) || parseBool(json['is_saved']),
      isFollowing: parseBool(json['isFollowing']) || parseBool(json['is_following']),
    );
  }

  // --- NEW: toJson for Hive Caching ---
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      // We manually reconstruct the user object structure to match fromJson expectation
      'user_id': {
        '_id': user.id,
        'username': user.username,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'profile_picture': user.profilePicture,
        'isFollowing': isFollowing, // Save follow status inside user object if needed
      },
      'video_url': videoUrl,
      'thumbnail': thumbnailUrl,
      'caption': caption,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'isFollowing': isFollowing,
    };
  }

  ReelEntity copyWith({
    bool? isLiked,
    int? likesCount,
    int? commentsCount,
    bool? isSaved,
    bool? isFollowing,
  }) {
    return ReelEntity(
      id: id,
      user: user,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [id, isLiked, isSaved, likesCount, commentsCount, isFollowing];
}