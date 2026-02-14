import 'package:equatable/equatable.dart';

class CallEntity extends Equatable {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPic;
  final String receiverId;
  final String type; // 'voice' or 'video'
  final String status; // 'ringing', 'accepted', 'rejected', 'ended'
  final String? channelId; // callId used as Agora channel

  const CallEntity({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPic,
    required this.receiverId,
    required this.type,
    required this.status,
    this.channelId,
  });

  /// Handles both formats:
  /// 1. Flat API response: { callId, callType, status }
  /// 2. Socket event with nested caller: { callId, caller: { _id, username, ... }, callType, status }
  factory CallEntity.fromJson(Map<String, dynamic> json) {
    final caller = json['caller'];
    return CallEntity(
      callId: json['callId'] ?? json['_id'] ?? '',
      callerId: caller is Map ? (caller['_id'] ?? '') : '',
      callerName: caller is Map ? (caller['username'] ?? 'Unknown') : '',
      callerPic: caller is Map ? (caller['profilePicture'] ?? '') : '',
      receiverId: json['receiver'] is Map
          ? (json['receiver']['_id'] ?? '')
          : (json['receiver'] ?? ''),
      type: json['callType'] ?? 'video',
      status: json['status'] ?? 'ringing',
      channelId: json['callId'] ?? json['_id'],
    );
  }

  @override
  List<Object?> get props => [callId, status];
}
