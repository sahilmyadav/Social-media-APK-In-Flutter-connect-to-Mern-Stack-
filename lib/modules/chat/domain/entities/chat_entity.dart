import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class ThreadEntity extends Equatable {
  final String id;
  final UserEntity participant; // The other person
  final String? lastMessage;
  final int unreadCount;
  final String updatedAt;

  const ThreadEntity({
    required this.id,
    required this.participant,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ThreadEntity.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Find the participant who is NOT me
    final participants = (json['participants'] as List);
    final otherUserJson = participants.firstWhere(
          (p) => p['_id'] != currentUserId,
      orElse: () => participants.first,
    );

    return ThreadEntity(
      id: json['_id'],
      participant: UserEntity.fromJson(otherUserJson),
      lastMessage: json['lastMessage']?['content'],
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: json['updatedAt'],
    );
  }

  @override
  List<Object?> get props => [id, lastMessage, unreadCount];
}

class MessageEntity extends Equatable {
  final String id;
  final String senderId;
  final String content;
  final String createdAt;
  final bool isMe;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.isMe,
  });

  factory MessageEntity.fromJson(Map<String, dynamic> json, String currentUserId) {
    final sender = json['sender_id'];
    final senderId = sender is Map ? sender['_id'] : sender; // Handle expanded or ID-only

    return MessageEntity(
      id: json['_id'] ?? '',
      senderId: senderId ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isMe: senderId == currentUserId,
    );
  }

  @override
  List<Object?> get props => [id, content, isMe];
}