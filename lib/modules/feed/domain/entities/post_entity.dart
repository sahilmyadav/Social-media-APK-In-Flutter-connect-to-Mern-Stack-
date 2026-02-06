import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class PostEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String caption;
  final List<MediaEntity> media;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final String createdAt;

  const PostEntity({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.isSaved,
    required this.createdAt,
  });

  factory PostEntity.fromJson(Map<dynamic, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json as Map);

    // --- HELPER: Parse Boolean from any type (int, string, bool) ---
    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return false;
    }

    // --- HELPER: Parse Saved Status (Greedy Check) ---
    // Since 'isSaved' is missing in /feed/home logs, we check alternatives
    bool checkSavedStatus() {
      if (safeJson.containsKey('isSaved')) return parseBool(safeJson['isSaved']);
      if (safeJson.containsKey('is_saved')) return parseBool(safeJson['is_saved']);
      if (safeJson.containsKey('saved')) return parseBool(safeJson['saved']);
      // Fallback: If saves_count > 0 and we can't determine, we default false
      // but this confirms the Backend needs to send this key!
      return false;
    }

    final userJson = safeJson['user_id'] ?? safeJson['user'] ?? {};
    final userEntity = UserEntity.fromJson(Map<String, dynamic>.from(userJson as Map));

    return PostEntity(
      id: safeJson['_id']?.toString() ?? safeJson['id']?.toString() ?? '',
      user: userEntity,
      caption: safeJson['caption']?.toString() ?? '',
      media: (safeJson['media'] as List? ?? [])
          .map((m) => MediaEntity.fromJson(m as Map))
          .toList(),
      likesCount: int.tryParse(safeJson['likes_count'].toString()) ?? 0,
      commentsCount: int.tryParse(safeJson['comments_count'].toString()) ?? 0,

      // PARSING BOOLEANS
      isLiked: parseBool(safeJson['isLiked']),
      isSaved: checkSavedStatus(), // Uses the greedy check

      createdAt: safeJson['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  PostEntity copyWith({
    bool? isLiked,
    int? likesCount,
    bool? isSaved,
    int? commentsCount,
    UserEntity? user,
  }) {
    return PostEntity(
      id: id,
      user: user ?? this.user,
      caption: caption,
      media: media,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, isLiked, isSaved, likesCount, commentsCount, user];
}

class MediaEntity extends Equatable {
  final String type;
  final String url;

  const MediaEntity({required this.type, required this.url});

  factory MediaEntity.fromJson(Map<dynamic, dynamic> json) {
    final map = Map<String, dynamic>.from(json as Map);
    return MediaEntity(
      type: map['type']?.toString() ?? 'image',
      url: map['url']?.toString() ?? '',
    );
  }

  bool get isValid => url.isNotEmpty && url != "/" && !url.contains("null");

  String get fullUrl {
    if (!isValid) return "";
    if (url.startsWith('http')) return url;
    String cleanUrl = url.startsWith('/') ? url : "/$url";
    return "https://clikkme.in$cleanUrl";
  }

  @override
  List<Object?> get props => [type, url];
}