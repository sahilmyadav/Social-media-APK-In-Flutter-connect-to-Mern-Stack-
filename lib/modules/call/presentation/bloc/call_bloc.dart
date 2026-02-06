import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/call_entity.dart';
import '../../../chat/data/repositories/chat_repository.dart';

// Events
abstract class CallEvent {}
class StartCallEvent extends CallEvent { final String receiverId; final String type; StartCallEvent(this.receiverId, this.type); }
class IncomingCallEvent extends CallEvent { final CallEntity call; IncomingCallEvent(this.call); }
class AcceptCallEvent extends CallEvent {}
class EndCallEvent extends CallEvent {}
class CallUpdatedEvent extends CallEvent { final String status; CallUpdatedEvent(this.status); }

// States
abstract class CallState {}
class CallIdle extends CallState {}
class CallRinging extends CallState { final CallEntity call; final bool isIncoming; CallRinging(this.call, {this.isIncoming = false}); }
class CallActive extends CallState { final String channelId; final RtcEngine engine; CallActive(this.channelId, this.engine); }
class CallEndedState extends CallState {}

class CallBloc extends Bloc<CallEvent, CallState> {
  final ChatRepository repository;
  StreamSubscription? _callSubscription;
  RtcEngine? _engine;
  CallEntity? _currentCall;

  // SAME AGORA ID AS MODULE 7
  static const String appId = "df22818f826f47ea95b385abe6f87b42";

  CallBloc(this.repository) : super(CallIdle()) {

    // Listen to Socket Events
    _callSubscription = repository.callStream.listen((call) {
      if (call.status == 'ringing') {
        add(IncomingCallEvent(call));
      } else if (call.status == 'accepted') {
        add(CallUpdatedEvent('accepted'));
      } else if (call.status == 'ended') {
        add(EndCallEvent());
      }
    });

    on<StartCallEvent>((event, emit) async {
      try {
        // 1. Request Call API
        final call = await repository.requestCall(event.receiverId, event.type);
        _currentCall = call;
        emit(CallRinging(call, isIncoming: false)); // Show "Calling..." UI
      } catch (e) {
        emit(CallEndedState());
      }
    });

    on<IncomingCallEvent>((event, emit) {
      _currentCall = event.call;
      emit(CallRinging(event.call, isIncoming: true)); // Show "Accept/Decline" UI
    });

    on<AcceptCallEvent>((event, emit) async {
      if (_currentCall != null) {
        await _initializeAgora(_currentCall!.channelId!);
        // Emit active state
        emit(CallActive(_currentCall!.channelId!, _engine!));
      }
    });

    on<CallUpdatedEvent>((event, emit) async {
      if (event.status == 'accepted' && state is CallRinging) {
        // Use the callId we started with
        await _initializeAgora(_currentCall!.channelId!);
        emit(CallActive(_currentCall!.channelId!, _engine!));
      }
    });

    on<EndCallEvent>((event, emit) async {
      if (_currentCall != null) {
        repository.endCall(_currentCall!.callId);
      }
      _engine?.leaveChannel();
      _engine?.release();
      _engine = null;
      _currentCall = null;
      emit(CallEndedState());
      await Future.delayed(const Duration(seconds: 1)); // Delay to show "Ended"
      emit(CallIdle());
    });
  }

  Future<void> _initializeAgora(String channelId) async {
    await [Permission.camera, Permission.microphone].request();
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: appId));
    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.joinChannel(
      token: "", // Testing Mode
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  Future<void> close() {
    _callSubscription?.cancel();
    return super.close();
  }
}