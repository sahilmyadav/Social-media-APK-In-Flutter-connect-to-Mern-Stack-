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

  /// Handles multiple formats:
  /// 1. Flat API response: { callId, callType, status }
  /// 2. Socket event with nested caller: { callId, caller: { _id, username, ... }, callType, status }
  /// 3. Socket event with caller as string ID: { callId, caller: "userId", callType, ... }
  /// 4. Socket event with top-level caller fields: { callId, callerId, callerName, ... }
  factory CallEntity.fromJson(Map<String, dynamic> json) {
    final caller = json['caller'];

    String callerId = '';
    String callerName = 'Unknown';
    String callerPic = '';

    if (caller is Map) {
      // Nested caller object — most common socket format
      callerId = caller['_id'] ?? caller['id'] ?? '';

      // Build name: prefer "firstName lastName", fallback to username/name/fullName
      final firstName = caller['firstName'] ?? '';
      final lastName = caller['lastName'] ?? '';
      final fullNameFromParts = '$firstName $lastName'.trim();
      callerName = fullNameFromParts.isNotEmpty
          ? fullNameFromParts
          : (caller['username'] ??
              caller['name'] ??
              caller['fullName'] ??
              'Unknown');

      callerPic = caller['profileImage'] ??
          caller['avatar'] ??
          caller['profilePicture'] ??
          caller['profilePic'] ??
          '';
    } else if (caller is String && caller.isNotEmpty) {
      // Caller sent as a plain string ID
      callerId = caller;
      callerName = json['callerName'] ?? json['username'] ?? 'Unknown';
      callerPic = json['callerPic'] ??
          json['profileImage'] ??
          json['avatar'] ??
          json['profilePicture'] ??
          '';
    } else {
      // No 'caller' field — check top-level fallback fields
      callerId = json['callerId'] ?? '';
      // Build name from top-level firstName/lastName if available
      final firstName = json['firstName'] ?? '';
      final lastName = json['lastName'] ?? '';
      final fullNameFromParts = '$firstName $lastName'.trim();
      callerName = fullNameFromParts.isNotEmpty
          ? fullNameFromParts
          : (json['callerName'] ?? json['username'] ?? 'Unknown');
      callerPic = json['callerPic'] ??
          json['profileImage'] ??
          json['avatar'] ??
          json['profilePicture'] ??
          '';
    }

    return CallEntity(
      callId: json['callId'] ?? json['_id'] ?? '',
      callerId: callerId,
      callerName: callerName,
      callerPic: callerPic,
      receiverId: json['receiver'] is Map
          ? (json['receiver']['_id'] ?? '')
          : (json['receiver'] ?? json['receiverId'] ?? ''),
      type: json['callType'] ?? json['type'] ?? 'video',
      status: json['status'] ?? 'ringing',
      channelId: json['callId'] ?? json['_id'],
    );
  }

  @override
  List<Object?> get props => [callId, status];
}
