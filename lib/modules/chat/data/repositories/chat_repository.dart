import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../../core/local_storage/hive_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../call/domain/entities/call_entity.dart';
import '../../domain/entities/chat_entity.dart';

class ChatRepository {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late IO.Socket _socket;

  // Cached current user info for outgoing calls
  Map<String, dynamic>? _cachedCurrentUser;

  // Streams
  final _messageController = StreamController<MessageEntity>.broadcast();
  Stream<MessageEntity> get messageStream => _messageController.stream;

  final _callController = StreamController<CallEntity>.broadcast();
  Stream<CallEntity> get callStream => _callController.stream;

  final _userStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStatusStream =>
      _userStatusController.stream;

  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

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

    _socket.on('user_status', (data) {
      if (!_userStatusController.isClosed) {
        _userStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('typing', (data) {
      if (!_typingController.isClosed) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket.on('stop_typing', (data) {
      if (!_typingController.isClosed) {
        _typingController.add(Map<String, dynamic>.from(data));
      }
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
      print("Incoming Call Raw Data: $data");
      try {
        final json = Map<String, dynamic>.from(data as Map);
        // Use the null-safe fromJson factory that handles both flat and nested formats
        final call = CallEntity.fromJson(json);
        print(
            "Parsed Incoming Call: callerId=${call.callerId}, callerName=${call.callerName}, callerPic=${call.callerPic}");
        _callController.add(call);
      } catch (e, stackTrace) {
        print("Call Parse Error: $e");
        print("Call Parse StackTrace: $stackTrace");
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
  Future<List<ThreadEntity>> getThreads() async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final response = await _apiClient.dio.get('/chat/threads');
    final responseData = response.data['data'];

    List threadsList;
    if (responseData is List) {
      threadsList = responseData;
    } else if (responseData is Map) {
      threadsList = responseData['threads'] ?? [];
    } else {
      threadsList = [];
    }

    // Cache the raw thread data for instant loading next time
    await HiveHelper.cacheThreads(
        threadsList.map((e) => Map<String, dynamic>.from(e as Map)).toList());

    return threadsList
        .map((e) => ThreadEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// Get cached threads for instant display while API loads
  Future<List<ThreadEntity>> getCachedThreads() async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final cached = HiveHelper.getCachedThreads();
    if (cached.isEmpty) return [];
    return cached
        .map((e) => ThreadEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// GET /chat/messages/:threadId
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

    // Cache messages for this thread
    await HiveHelper.cacheMessages(threadId,
        messagesList.map((e) => Map<String, dynamic>.from(e as Map)).toList());

    return messagesList
        .map((e) => MessageEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// Get cached messages for instant display
  Future<List<MessageEntity>> getCachedMessages(String threadId) async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';
    final cached = HiveHelper.getCachedMessages(threadId);
    if (cached.isEmpty) return [];
    return cached
        .map((e) => MessageEntity.fromJson(
            Map<String, dynamic>.from(e as Map), currentUserId))
        .toList();
  }

  /// POST /chat/upload
  Future<String> uploadMedia(File file) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await _apiClient.dio.post('/chat/upload', data: formData);
    return response.data['data']['url'];
  }

  /// POST /chat/message/send/:threadId
  /// Supports both JSON (text only) and FormData (media).
  Future<MessageEntity> sendMessage(String threadId, String content,
      {String type = 'text',
      File? mediaFile,
      File? thumbnailFile,
      String?
          mediaUrl, // Keep for backward compatibility or if URL is already available
      String? thumbnailUrl,
      int? duration}) async {
    final currentUserId = await _storage.read(key: 'userId') ?? '';

    Response response;

    if (mediaFile != null || thumbnailFile != null) {
      // Use FormData for file uploads
      final Map<String, dynamic> map = {
        "text": content,
        "type": type,
        if (duration != null) "duration": duration,
        if (mediaUrl != null) "mediaUrl": mediaUrl,
      };

      if (mediaFile != null) {
        if (await mediaFile.exists()) {
          String fileName = mediaFile.path.split('/').last;

          MediaType? contentType;
          if (type == 'audio' || type == 'voice') {
            contentType = MediaType('audio', 'm4a');
          } else if (type == 'image') {
            contentType = MediaType('image', 'jpeg');
          } else if (type == 'video') {
            contentType = MediaType('video', 'mp4');
          }

          map["media"] = await MultipartFile.fromFile(mediaFile.path,
              filename: fileName, contentType: contentType);
        } else {
          debugPrint("❌ Error: Media file does not exist at ${mediaFile.path}");
          throw Exception("Media file not found");
        }
      }

      if (thumbnailFile != null) {
        String thumbName = thumbnailFile.path.split('/').last;
        map["thumbnail"] = await MultipartFile.fromFile(thumbnailFile.path,
            filename: thumbName);
      }

      final formData = FormData.fromMap(map);

      response = await _apiClient.dio
          .post('/chat/message/send/$threadId', data: formData);
    } else {
      debugPrint("🚀 Sending Text Message Payload: ${{
        "text": content,
        "type": type,
        if (mediaUrl != null) "mediaUrl": mediaUrl,
        if (thumbnailUrl != null) "thumbnailUrl": thumbnailUrl,
        if (duration != null) "duration": duration
      }}");

      response =
          await _apiClient.dio.post('/chat/message/send/$threadId', data: {
        "text": content,
        "type": type,
        if (mediaUrl != null) "mediaUrl": mediaUrl,
        if (thumbnailUrl != null) "thumbnailUrl": thumbnailUrl,
        if (duration != null) "duration": duration
      });
      debugPrint("✅ Message Text Sent Response: ${response.data}");
    }

    // debugPrint("✅ Message Sent Response: ${response.data}"); // Removed duplicate log
    final messageData = Map<String, dynamic>.from(response.data['data'] as Map);
    return MessageEntity.fromJson(messageData, currentUserId);
  }

  /// POST /chat/thread/:receiverId
  Future<String> createThread(String receiverId) async {
    final response = await _apiClient.dio.post('/chat/thread/$receiverId');
    final data = response.data['data'];
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
        .put('/chat/message/edit/$messageId', data: {"text": content});
  }

  /// PUT /chat/messages/seen/:threadId
  Future<void> markMessagesSeen(String threadId) async {
    await _apiClient.dio.put('/chat/messages/seen/$threadId');
  }

  /// POST /chat/call/request/:receiverId
  Future<CallEntity> requestCall(String receiverId, String type) async {
    // Fetch current user info to send caller details with the call request
    // so the receiver (website) can display the caller's name and picture.
    if (_cachedCurrentUser == null) {
      try {
        final userResp = await _apiClient.dio.get('/users/current-user');
        _cachedCurrentUser = Map<String, dynamic>.from(userResp.data['data']);
      } catch (e) {
        debugPrint('Failed to fetch current user for call: $e');
      }
    }

    final callerName =
        '${_cachedCurrentUser?['firstName'] ?? ''} ${_cachedCurrentUser?['lastName'] ?? ''}'
            .trim();

    final response =
        await _apiClient.dio.post('/chat/call/request/$receiverId', data: {
      "callType": type,
      "callerName": callerName.isNotEmpty ? callerName : 'Unknown',
      "callerPic": _cachedCurrentUser?['profilePicture'] ?? '',
      "callerId": _cachedCurrentUser?['_id'] ?? '',
      "callerUsername": _cachedCurrentUser?['username'] ?? '',
    });
    return CallEntity.fromJson(response.data['data']);
  }

  /// POST /chat/call/end/:callId
  Future<void> endCall(String callId, {int duration = 0}) async {
    await _apiClient.dio.post('/chat/call/end/$callId', data: {
      "duration": duration,
    });
  }

  /// POST /chat/call/accept/:callId
  Future<void> acceptCall(String callId) async {
    await _apiClient.dio.post('/chat/call/accept/$callId');
  }

  void sendTyping(String threadId, String receiverId) {
    _socket.emit('typing', {'threadId': threadId, 'receiverId': receiverId});
  }

  void sendStopTyping(String threadId, String receiverId) {
    _socket
        .emit('stop_typing', {'threadId': threadId, 'receiverId': receiverId});
  }

  void dispose() {
    _socket.disconnect();
    _messageController.close();
    _callController.close();
    _typingController.close();
  }
}
