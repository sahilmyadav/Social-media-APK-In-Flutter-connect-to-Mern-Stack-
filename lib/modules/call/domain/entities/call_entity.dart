import 'package:equatable/equatable.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class CallEntity extends Equatable {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPic;
  final String receiverId;
  final String type; // 'voice' or 'video'
  final String status; // 'ringing', 'accepted', 'rejected', 'ended'
  final String? channelId; // We use callId as channelId for Agora

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

  factory CallEntity.fromJson(Map<String, dynamic> json) {
    return CallEntity(
      callId: json['callId'] ?? json['_id'] ?? '',
      callerId: json['caller']?['_id'] ?? '',
      callerName: json['caller']?['username'] ?? 'Unknown',
      callerPic: json['caller']?['profilePicture'] ?? '',
      receiverId: json['receiver']?['_id'] ?? '',
      type: json['callType'] ?? 'video',
      status: json['status'] ?? 'ringing',
      channelId: json['callId'] ?? json['_id'], // Use callId as Agora Channel
    );
  }

  @override
  List<Object?> get props => [callId, status];
}