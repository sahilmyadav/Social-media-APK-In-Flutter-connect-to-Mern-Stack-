import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_entity.dart';
import '../../data/repositories/chat_repository.dart';

// Events
abstract class ChatEvent {}
class InitChat extends ChatEvent {}
class LoadThreads extends ChatEvent {}
class LoadMessages extends ChatEvent { final String threadId; LoadMessages(this.threadId); }
class SendMessageEvent extends ChatEvent { final String threadId; final String content; SendMessageEvent(this.threadId, this.content); }
class ReceiveMessageEvent extends ChatEvent { final MessageEntity message; ReceiveMessageEvent(this.message); }

// States
abstract class ChatState {}
class ChatInitial extends ChatState {}
class ThreadsLoaded extends ChatState { final List<ThreadEntity> threads; ThreadsLoaded(this.threads); }
class MessagesLoaded extends ChatState { final List<MessageEntity> messages; MessagesLoaded(this.messages); }
class ChatError extends ChatState { final String message; ChatError(this.message); }

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;
  StreamSubscription? _messageSubscription;

  ChatBloc(this.repository) : super(ChatInitial()) {

    on<InitChat>((event, emit) async {
      try {
        await repository.initSocket();
        // Listen to the stream from Repository
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
        final threads = await repository.getThreads();
        emit(ThreadsLoaded(threads));
      } catch (e) {
        emit(ChatError("Failed to load chats"));
      }
    });

    on<LoadMessages>((event, emit) async {
      try {
        final messages = await repository.getMessages(event.threadId);
        emit(MessagesLoaded(messages));
      } catch (e) {
        emit(ChatError("Failed to load messages"));
      }
    });

    on<SendMessageEvent>((event, emit) async {
      try {
        // Optimistic UI update could go here
        await repository.sendMessage(event.threadId, event.content);
      } catch (e) {
        emit(ChatError("Failed to send message"));
      }
    });

    on<ReceiveMessageEvent>((event, emit) {
      if (state is MessagesLoaded) {
        final currentMessages = (state as MessagesLoaded).messages;
        // Add new message to the list
        emit(MessagesLoaded(List.from(currentMessages)..add(event.message)));
      }
    });
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}