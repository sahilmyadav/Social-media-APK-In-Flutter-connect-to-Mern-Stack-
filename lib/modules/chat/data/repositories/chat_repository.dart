import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/chat_entity.dart';
import '../../../call/domain/entities/call_entity.dart';

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

    _socket = IO.io(
        'https://clikkme.in',
        IO.OptionBuilder()
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
        final messageJson = Map<String, dynamic>.from(data as Map);
        _messageController
            .add(MessageEntity.fromJson(messageJson, currentUserId));
      } catch (e) {
        print("Message Parse Error: $e");
      }
    });

    _socket.on('call_incoming', (data) {
      print("Incoming Call: $data");
      try {
        final call = CallEntity(
          callId: data['callId'],
          callerId: data['caller']['_id'],
          callerName: data['caller']['username'],
          callerPic: data['caller']['profilePicture'],
          receiverId: '',
          type: data['callType'],
          status: 'ringing',
          channelId: data['callId'],
        );
        _callController.add(call);
      } catch (e) {
        print("Call Parse Error: $e");
      }
    });

    _socket.on('call_accepted', (data) {
      _callController.add(CallEntity(
        callId: data['callId'],
        callerId: '',
        callerName: '',
        callerPic: '',
        receiverId: '',
        type: 'video',
        status: 'accepted',
      ));
    });

    _socket.on('call_ended', (data) {
      _callController.add(CallEntity(
        callId: data['callId'] ?? '',
        callerId: '',
        callerName: '',
        callerPic: '',
        receiverId: '',
        type: 'video',
        status: 'ended',
      ));
    });
  }

  // --- Chat APIs ---

  /// GET /chat/threads
  /// API spec says data is array, actual API wraps in data.threads - handle both.
  Future<List<ThreadEntity>> getThreads() async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio.get('/chat/threads');
    final responseData = response.data['data'];

    List threadsList;
    if (responseData is List) {
      // API spec format: data is directly an array
      threadsList = responseData;
    } else if (responseData is Map) {
      // Actual API format: data.threads is the array
      threadsList = responseData['threads'] ?? [];
    } else {
      threadsList = [];
    }

    return threadsList
        .map((e) => ThreadEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// GET /chat/messages/:threadId
  /// Response: { data: { messages: [...], total, page, hasMore } }
  Future<List<MessageEntity>> getMessages(String threadId) async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio.get('/chat/messages/$threadId');
    final responseData = response.data['data'];

    List messagesList;
    if (responseData is List) {
      messagesList = responseData;
    } else if (responseData is Map) {
      messagesList = responseData['messages'] ?? [];
    } else {
      messagesList = [];
    }

    return messagesList
        .map((e) => MessageEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// POST /chat/message/send/:threadId
  /// Request: { "content": "..." }
  /// Response (201): { data: { _id, thread_id, sender_id: {...}, content, media, status, createdAt } }
  Future<MessageEntity> sendMessage(String threadId, String content) async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio
        .post('/chat/message/send/$threadId', data: {"content": content});
    final messageData = Map<String, dynamic>.from(response.data['data'] as Map);
    return MessageEntity.fromJson(messageData, currentUserId);
  }

  /// POST /chat/thread/:receiverId
  /// Response: { data: { _id, participants: [...], createdAt } }
  Future<String> createThread(String receiverId) async {
    final response = await _apiClient.dio.post('/chat/thread/$receiverId');
    final data = response.data['data'];
    // The response data contains _id for the thread
    return data['_id'] ?? data['id'] ?? '';
  }

  /// DELETE /chat/thread/delete/:threadId
  Future<void> deleteThread(String threadId) async {
    await _apiClient.dio.delete('/chat/thread/delete/$threadId');
  }

  /// DELETE /chat/message/delete/:messageId
  Future<void> deleteMessage(String messageId) async {
    await _apiClient.dio.delete('/chat/message/delete/$messageId');
  }

  /// PUT /chat/message/edit/:messageId
  Future<void> editMessage(String messageId, String content) async {
    await _apiClient.dio
        .put('/chat/message/edit/$messageId', data: {"content": content});
  }

  /// PUT /chat/messages/seen/:threadId
  Future<void> markMessagesSeen(String threadId) async {
    await _apiClient.dio.put('/chat/messages/seen/$threadId');
  }

  /// POST /chat/call/request/:receiverId
  Future<CallEntity> requestCall(String receiverId, String type) async {
    final response = await _apiClient.dio
        .post('/chat/call/request/$receiverId', data: {"callType": type});
    return CallEntity.fromJson(response.data['data']);
  }

  /// POST /chat/call/end/:callId
  Future<void> endCall(String callId) async {
    await _apiClient.dio.post('/chat/call/end/$callId');
  }

  void dispose() {
    _socket.disconnect();
    _messageController.close();
    _callController.close();
  }
}
