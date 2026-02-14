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
      final lm = json['lastMessage'];
      final text = lm['text']?.toString() ?? lm['content']?.toString();
      final type = lm['type']?.toString();

      if (text != null && text.isNotEmpty) {
        lastMessageContent = text;
      } else if (type != null) {
        switch (type) {
          case 'image':
            lastMessageContent = "[Photo]";
            break;
          case 'video':
            lastMessageContent = "[Video]";
            break;
          case 'audio':
            lastMessageContent = "[Audio]";
            break;
          case 'location':
            lastMessageContent = "[Location]";
            break;
          default:
            lastMessageContent = null;
        }
      }
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
  final String type; // 'text', 'audio', 'image', 'video'
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? threadId;
  final int? duration;

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.isMe,
    this.status,
    this.type = 'text',
    this.mediaUrl,
    this.thumbnailUrl,
    this.threadId,
    this.duration,
  });

  factory MessageEntity.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    // sender_id / senderId can be either:
    // - An expanded object: { "_id": "64f...", "firstName": "John", ... }
    // - A plain string ID: "64f..."
    final sender = json['sender_id'] ?? json['senderId'];
    final String senderId;
    if (sender is Map) {
      senderId = sender['_id']?.toString() ?? '';
    } else {
      senderId = sender?.toString() ?? '';
    }

    String? parsedMediaUrl = json['mediaUrl'];
    if (parsedMediaUrl == null) {
      if (json['file'] is String) {
        parsedMediaUrl = json['file'];
      } else if (json['file'] is Map && json['file']['url'] != null) {
        parsedMediaUrl = json['file']['url'];
      } else if (json['url'] is String) {
        parsedMediaUrl = json['url'];
      } else if (json['media'] is Map && json['media']['url'] != null) {
        parsedMediaUrl = json['media']['url'];
      } else if (json['media'] is String) {
        parsedMediaUrl = json['media'];
      }
    }

    // Extract type from nested objects if not at root
    String type = json['type'] ?? 'text';
    if (type == 'text' &&
        (parsedMediaUrl != null && parsedMediaUrl.isNotEmpty)) {
      if (json['file'] is Map && json['file']['type'] != null) {
        type = json['file']['type'];
      } else if (json['media'] is Map && json['media']['type'] != null) {
        type = json['media']['type'];
      }
      // Fallback: guess from extension? (optional, but let's stick to explicit type for now)
    }

    // Ensure type is valid (image/video/audio)
    if (type != 'text' &&
        type != 'image' &&
        type != 'video' &&
        type != 'audio' &&
        type != 'location') {
      // Map common variations if any, e.g. 'photo' -> 'image'
      if (type == 'photo') type = 'image';
    }

    if (parsedMediaUrl != null &&
        parsedMediaUrl.isNotEmpty &&
        !parsedMediaUrl.startsWith('http')) {
      parsedMediaUrl =
          "https://clikkme.in${parsedMediaUrl.startsWith('/') ? '' : '/'}$parsedMediaUrl";
    }

    return MessageEntity(
      id: json['_id'] ?? '',
      senderId: senderId,
      content: json['text'] ?? json['content'] ?? '',
      createdAt: json['createdAt'] ?? '',
      isMe: senderId == currentUserId,
      status: json['status']?.toString(),
      type: type,
      mediaUrl: parsedMediaUrl,
      thumbnailUrl: json['thumbnailUrl'],
      threadId: json['threadId']?.toString(),
      duration: int.tryParse(json['duration']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [
        id,
        content,
        isMe,
        status,
        type,
        mediaUrl,
        thumbnailUrl,
        threadId,
        duration
      ];
}
