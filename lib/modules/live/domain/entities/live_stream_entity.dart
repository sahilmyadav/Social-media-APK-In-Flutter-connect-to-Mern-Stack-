import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class LiveStreamEntity extends Equatable {
  final String id;
  final UserEntity? user;
  final String title;
  final String description;
  final String thumbnail;
  final String status; // 'created', 'live', 'ended'
  final String streamKey;
  final String rtmpUrl;
  final String? playbackUrl;
  final int viewersCount;
  final String createdAt;
  final String? startedAt;
  final String? endedAt;

  const LiveStreamEntity({
    required this.id,
    this.user,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.status,
    required this.streamKey,
    required this.rtmpUrl,
    this.playbackUrl,
    required this.viewersCount,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory LiveStreamEntity.fromJson(Map<String, dynamic> json) {
    return LiveStreamEntity(
      id: json['_id'] ?? '',
      user: json['user_id'] is Map<String, dynamic>
          ? UserEntity.fromJson(json['user_id'])
          : null,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      status: json['status'] ?? 'created',
      streamKey: json['streamKey'] ?? '',
      rtmpUrl: json['rtmpUrl'] ?? '',
      playbackUrl: json['playbackUrl'],
      viewersCount: json['viewers_count'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      startedAt: json['startedAt'],
      endedAt: json['endedAt'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        user,
        title,
        status,
        viewersCount,
        streamKey,
        rtmpUrl,
        playbackUrl,
        createdAt
      ];
}
