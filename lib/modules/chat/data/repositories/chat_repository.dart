import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../call/domain/entities/call_entity.dart'; // Import CallEntity

class ChatRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late IO.Socket _socket;

  // Streams
  final _messageController = StreamController<MessageEntity>.broadcast();
  Stream<MessageEntity> get messageStream => _messageController.stream;

  final _callController = StreamController<CallEntity>.broadcast();
  Stream<CallEntity> get callStream => _callController.stream;

  ChatRepository(this._apiClient);

  Future<void> initSocket() async {
    final token = await _storage.read(key: 'accessToken');

    _socket = IO.io('https://clikkme.in', IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build());

    _socket.connect();

    _socket.onConnect((_) {
      print('Socket Connected');
      _socket.emit('authenticate', {'token': token});
    });

    // 1. New Message Event
    _socket.on('new_message', (data) async {
      final currentUserId = await _storage.read(key: 'userId') ?? '';
      try {
        _messageController.add(MessageEntity.fromJson(data, currentUserId));
      } catch (e) {
        print("Message Parse Error: $e");
      }
    });


    _socket.on('call_incoming', (data) {
      print("Incoming Call: $data");
      try {
        // Map raw socket data to CallEntity
        final call = CallEntity(
          callId: data['callId'],
          callerId: data['caller']['_id'],
          callerName: data['caller']['username'],
          callerPic: data['caller']['profilePicture'],
          receiverId: '', // Me
          type: data['callType'],
          status: 'ringing',
          channelId: data['callId'],
        );
        _callController.add(call);
      } catch (e) {
        print("Call Parse Error: $e");
      }
    });

    // 3. Call Accepted Event
    _socket.on('call_accepted', (data) {
      _callController.add(CallEntity(
        callId: data['callId'],
        callerId: '', callerName: '', callerPic: '', receiverId: '',
        type: 'video',
        status: 'accepted',
      ));
    });

    // 4. Call Ended/Rejected
    _socket.on('call_ended', (data) {
      _callController.add(CallEntity(
        callId: data['callId'] ?? '',
        callerId: '', callerName: '', callerPic: '', receiverId: '',
        type: 'video',
        status: 'ended',
      ));
    });
  }

  // --- Chat APIs ---
  Future<List<ThreadEntity>> getThreads() async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio.get('/chat/threads');
    final List data = response.data['data'];
    return data.map((e) => ThreadEntity.fromJson(e, currentUserId)).toList();
  }

  Future<List<MessageEntity>> getMessages(String threadId) async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio.get('/chat/messages/$threadId');
    final List data = response.data['data']['messages'];
    return data.map((e) => MessageEntity.fromJson(e, currentUserId)).toList();
  }

  Future<void> sendMessage(String threadId, String content) async {
    await _apiClient.dio.post('/chat/message/send/$threadId', data: {"content": content});
  }

  Future<String> createThread(String receiverId) async {
    final response = await _apiClient.dio.post('/chat/thread/$receiverId');
    return response.data['data']['id'] ?? response.data['data']['_id'];
  }


  Future<CallEntity> requestCall(String receiverId, String type) async {
    final response = await _apiClient.dio.post('/chat/call/request/$receiverId', data: {
      "callType": type
    });
    // Return initial call state
    return CallEntity.fromJson(response.data['data']);
  }

  Future<void> endCall(String callId) async {
    await _apiClient.dio.post('/chat/call/end/$callId');
  }

  void dispose() {
    _socket.disconnect();
    _messageController.close();
    _callController.close();
  }
}