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
    List<StoryItemEntity> storyList = list.map((i) => StoryItemEntity.fromJson(i)).toList();

    // Check if any story is unseen
    bool unseen = storyList.any((s) => !s.hasViewed);

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
  final String createdAt;

  const StoryItemEntity({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    required this.hasViewed,
    required this.createdAt,
  });

  factory StoryItemEntity.fromJson(Map<String, dynamic> json) {
    return StoryItemEntity(
      id: json['_id'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'] ?? 'image',
      caption: json['caption'] ?? '',
      hasViewed: json['hasViewed'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  @override
  List<Object?> get props => [id, hasViewed];
}