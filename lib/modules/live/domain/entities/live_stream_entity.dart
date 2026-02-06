import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class LiveStreamEntity extends Equatable {
  final String id;
  final UserEntity user;
  final String title;
  final String status; // 'created', 'live', 'ended'
  final String channelId; // Used for Agora Channel
  final String token; // Agora Token (if API provides it, else we use placeholder)
  final int viewersCount;

  const LiveStreamEntity({
    required this.id,
    required this.user,
    required this.title,
    required this.status,
    required this.channelId,
    required this.token,
    required this.viewersCount,
  });

  factory LiveStreamEntity.fromJson(Map<String, dynamic> json) {
    return LiveStreamEntity(
      id: json['_id'] ?? '',
      user: UserEntity.fromJson(json['user_id'] ?? {}),
      title: json['title'] ?? '',
      status: json['status'] ?? 'created',
      channelId: json['streamKey'] ?? '', // Using streamKey as channel name
      token: json['token'] ?? '', // Ensure your API returns an Agora Token
      viewersCount: json['viewers_count'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, status, viewersCount];
}