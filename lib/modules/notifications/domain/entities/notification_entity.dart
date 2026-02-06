import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String recipientId;
  final UserEntity sender;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final String title;
  final String message;
  final bool isRead;
  final String? actionUrl;
  final String createdAt;
  final String? thumbnail;
  final bool isFollowedBack;

  const NotificationEntity({
    required this.id,
    required this.recipientId,
    required this.sender,
    required this.type,
    this.referenceId,
    this.referenceType,
    required this.title,
    required this.message,
    required this.isRead,
    this.actionUrl,
    required this.createdAt,
    this.thumbnail,
    this.isFollowedBack = false,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    // Robust sender parsing
    final senderData = (json['sender_id'] != null && json['sender_id'] is Map<String, dynamic>)
        ? json['sender_id']
        : {'username': 'Unknown', '_id': '', 'firstName': 'Unknown'};

    return NotificationEntity(
      id: json['_id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      sender: UserEntity.fromJson(senderData),
      type: json['type'] ?? 'unknown',
      referenceId: json['reference_id']?.toString(),
      referenceType: json['reference_type'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      actionUrl: json['action_url'],
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      thumbnail: json['thumbnail'],
      // Logic: if 'isFollowing' is in sender, use it. Or check local flag.
      isFollowedBack: senderData['isFollowing'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'recipient_id': recipientId,
      'sender_id': {
        '_id': sender.id,
        'username': sender.username,
        'firstName': sender.firstName,
        'lastName': sender.lastName,
        'profilePicture': sender.profilePicture,
        'isFollowing': isFollowedBack, // IMPORTANT: Save this state to Hive
      },
      'type': type,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'title': title,
      'message': message,
      'is_read': isRead,
      'action_url': actionUrl,
      'createdAt': createdAt,
      'thumbnail': thumbnail,
    };
  }

  NotificationEntity copyWith({
    bool? isRead,
    bool? isFollowedBack,
    UserEntity? sender, // Added this
  }) {
    return NotificationEntity(
      id: id,
      recipientId: recipientId,
      sender: sender ?? this.sender, // Use updated sender if provided
      type: type,
      referenceId: referenceId,
      referenceType: referenceType,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl,
      createdAt: createdAt,
      thumbnail: thumbnail,
      isFollowedBack: isFollowedBack ?? this.isFollowedBack,
    );
  }

  @override
  List<Object?> get props => [id, isRead, isFollowedBack, sender];
}