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

  factory ThreadEntity.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    // The API can return participant data in two ways:
    // 1. "participant": { ... }  (singular object - actual API behavior)
    // 2. "participants": [ ... ] (array - per API spec)
    // We handle BOTH for robustness.

    Map<String, dynamic> otherUserJson = {};

    if (json['participant'] != null && json['participant'] is Map) {
      // Case 1: Singular "participant" object (actual API response)
      otherUserJson = Map<String, dynamic>.from(json['participant']);
    } else if (json['participants'] != null && json['participants'] is List) {
      // Case 2: "participants" array (API spec format)
      final participants = json['participants'] as List;
      final found = participants.firstWhere(
        (p) => p['_id'] != currentUserId,
        orElse: () => participants.isNotEmpty ? participants.first : {},
      );
      otherUserJson = Map<String, dynamic>.from(found);
    }

    // Handle lastMessage which can be a Map or null
    String? lastMessageContent;
    if (json['lastMessage'] != null && json['lastMessage'] is Map) {
      lastMessageContent = json['lastMessage']['content']?.toString();
    }

    return ThreadEntity(
      id: json['_id'] ?? '',
      participant: UserEntity.fromJson(otherUserJson),
      lastMessage: lastMessageContent,
      unreadCount: int.tryParse(json['unreadCount'].toString()) ?? 0,
      updatedAt: json['updatedAt'] ?? json['lastMessageAt'] ?? '',
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
  final String? status; // "sent", "delivered", "read"

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.isMe,
    this.status,
  });

  factory MessageEntity.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    // sender_id can be either:
    // - An expanded object: { "_id": "64f...", "firstName": "John", ... }
    // - A plain string ID: "64f..."
    final sender = json['sender_id'];
    final String senderId;
    if (sender is Map) {
      senderId = sender['_id']?.toString() ?? '';
    } else {
      senderId = sender?.toString() ?? '';
    }

    return MessageEntity(
      id: json['_id'] ?? '',
      senderId: senderId,
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isMe: senderId == currentUserId,
      status: json['status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, content, isMe];
}
