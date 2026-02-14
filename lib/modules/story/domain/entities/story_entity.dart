import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class StoryFeedEntity extends Equatable {
  final UserEntity user;
  final List<StoryItemEntity> stories;
  final bool hasUnseen;

  const StoryFeedEntity({
    required this.user,
    required this.stories,
    required this.hasUnseen,
  });

  factory StoryFeedEntity.fromJson(Map<String, dynamic> json) {
    var list = json['stories'] as List;
    List<StoryItemEntity> storyList =
        list.map((i) => StoryItemEntity.fromJson(i)).toList();

    // Check if any story is unseen
    bool unseen =
        json['hasUnseenStories'] ?? storyList.any((s) => !s.hasViewed);

    return StoryFeedEntity(
      user: UserEntity.fromJson(json['user']),
      stories: storyList,
      hasUnseen: unseen,
    );
  }

  @override
  List<Object?> get props => [user, stories, hasUnseen];
}

class StoryItemEntity extends Equatable {
  final String id;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String caption;
  final bool hasViewed;
  final int viewsCount;
  final int duration;
  final String createdAt;

  const StoryItemEntity({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    required this.hasViewed,
    this.viewsCount = 0,
    this.duration = 5,
    required this.createdAt,
  });

  factory StoryItemEntity.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    String parsedMediaUrl = '';
    String parsedMediaType = 'image';

    if (media is Map<String, dynamic>) {
      parsedMediaUrl = media['url'] ?? '';
      parsedMediaType = media['type'] ?? 'image';
    } else {
      parsedMediaUrl = json['media_url'] ?? '';
      parsedMediaType = json['media_type'] ?? 'image';
    }

    return StoryItemEntity(
      id: json['_id'] ?? '',
      mediaUrl: parsedMediaUrl,
      mediaType: parsedMediaType,
      caption: json['caption'] ?? '',
      hasViewed: json['hasViewed'] ?? false,
      viewsCount: json['views_count'] ?? 0,
      duration:
          (json['duration'] is num) ? (json['duration'] as num).toInt() : 5,
      createdAt: json['createdAt'] ?? '',
    );
  }

  @override
  List<Object?> get props => [id, hasViewed, viewsCount];
}
