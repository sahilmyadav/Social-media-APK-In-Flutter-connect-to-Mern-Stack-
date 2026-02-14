import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/repositories/chat_repository.dart';

// Events
abstract class ChatEvent {}

class InitChat extends ChatEvent {}

class LoadThreads extends ChatEvent {}

class LoadMessages extends ChatEvent {
  final String threadId;
  LoadMessages(this.threadId);
}

class SendMessageEvent extends ChatEvent {
  final String threadId;
  final String content;
  final String type;
  SendMessageEvent(this.threadId, this.content, {this.type = 'text'});
}

class SendMediaMessageEvent extends ChatEvent {
  final String threadId;
  final File file;
  final String type; // 'image', 'video', 'audio'
  final int? duration;

  SendMediaMessageEvent(this.threadId, this.file, this.type, {this.duration});
}

class ReceiveMessageEvent extends ChatEvent {
  final MessageEntity message;
  ReceiveMessageEvent(this.message);
}

class DeleteMessageEvent extends ChatEvent {
  final String messageId;
  DeleteMessageEvent(this.messageId);
}

// States
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ThreadsLoaded extends ChatState {
  final List<ThreadEntity> threads;
  ThreadsLoaded(this.threads);
}

class MessagesLoaded extends ChatState {
  final List<MessageEntity> messages;
  final String threadId;
  MessagesLoaded(this.messages, this.threadId);
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;
  StreamSubscription? _messageSubscription;

  ChatBloc(this.repository) : super(ChatInitial()) {
    on<InitChat>((event, emit) async {
      try {
        await repository.initSocket();
        _messageSubscription?.cancel();
        _messageSubscription = repository.messageStream.listen((message) {
          add(ReceiveMessageEvent(message));
        });
      } catch (e) {
        print("Socket Init Error: $e");
      }
    });

    on<LoadThreads>((event, emit) async {
      try {
        // 1. Show cached threads instantly (no loading spinner)
        final cached = await repository.getCachedThreads();
        if (cached.isNotEmpty) {
          emit(ThreadsLoaded(cached));
        }

        // 2. Fetch fresh threads from API
        final threads = await repository.getThreads();
        emit(ThreadsLoaded(threads));
      } catch (e) {
        // If we already showed cached data, don't emit error
        if (state is! ThreadsLoaded) {
          emit(ChatError("Failed to load chats: $e"));
        }
      }
    });

    on<LoadMessages>((event, emit) async {
      try {
        // 1. Show cached messages instantly
        final cached = await repository.getCachedMessages(event.threadId);
        if (cached.isNotEmpty) {
          emit(MessagesLoaded(cached, event.threadId));
        } else {
          emit(ChatLoading());
        }

        // 2. Fetch fresh messages from API
        final messages = await repository.getMessages(event.threadId);
        emit(MessagesLoaded(messages, event.threadId));
      } catch (e) {
        if (state is! MessagesLoaded) {
          emit(ChatError("Failed to load messages: $e"));
        }
      }
    });

    on<SendMessageEvent>((event, emit) async {
      debugPrint(
          "🚀 ChatBloc: Received SendMessageEvent for thread ${event.threadId} with content: ${event.content}");
      try {
        // Send the message via API, which returns the sent MessageEntity
        final sentMessage = await repository
            .sendMessage(event.threadId, event.content, type: event.type);

        // Update UI immediately with the new message
        if (state is MessagesLoaded &&
            (state as MessagesLoaded).threadId == event.threadId) {
          final currentMessages = (state as MessagesLoaded).messages;
          emit(MessagesLoaded(
              List.from(currentMessages)..add(sentMessage), event.threadId));
        } else {
          // If not in MessagesLoaded state, just reload
          add(LoadMessages(event.threadId));
        }
      } catch (e, stackTrace) {
        debugPrint("❌ ChatBloc Error (SendMessage): $e");
        debugPrint(stackTrace.toString());
        emit(ChatError("Failed to send message: $e"));
      }
    });

    on<SendMediaMessageEvent>((event, emit) async {
      debugPrint(
          "🚀 ChatBloc: Received SendMediaMessageEvent for thread ${event.threadId}, type: ${event.type}, path: ${event.file.path}");
      try {
        // Send message directly with file (FormData handled in repo)
        final sentMessage = await repository.sendMessage(
            event.threadId, "", // content is empty for media
            type: event.type,
            mediaFile: event.file,
            duration: event.duration);

        if (state is MessagesLoaded &&
            (state as MessagesLoaded).threadId == event.threadId) {
          final currentMessages = (state as MessagesLoaded).messages;
          emit(MessagesLoaded(
              List.from(currentMessages)..add(sentMessage), event.threadId));
        } else {
          add(LoadMessages(event.threadId));
        }
      } catch (e, stackTrace) {
        debugPrint("❌ ChatBloc Error (SendMedia): $e");
        debugPrint(stackTrace.toString());
        emit(ChatError("Failed to send ${event.type}: $e"));
      }
    });

    on<ReceiveMessageEvent>((event, emit) {
      if (state is MessagesLoaded) {
        final currentState = state as MessagesLoaded;
        // Verify Thread ID Matches!
        if (event.message.threadId != null &&
            event.message.threadId != currentState.threadId) {
          return; // Message is for another thread
        }

        final currentMessages = currentState.messages;
        // Avoid duplicate messages
        final exists = currentMessages.any((m) => m.id == event.message.id);
        if (!exists) {
          emit(MessagesLoaded(List.from(currentMessages)..add(event.message),
              currentState.threadId));
        }
      }
    });

    on<DeleteMessageEvent>((event, emit) async {
      if (state is MessagesLoaded) {
        final currentState = state as MessagesLoaded;
        // Optimistic Delete
        final updatedMessages = currentState.messages
            .where((m) => m.id != event.messageId)
            .toList();
        emit(MessagesLoaded(updatedMessages, currentState.threadId));

        try {
          await repository.deleteMessage(event.messageId);
        } catch (e) {
          // Revert if failed (optional, or just show error)
          emit(ChatError("Failed to delete message: $e"));
          add(LoadMessages(currentState.threadId));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
