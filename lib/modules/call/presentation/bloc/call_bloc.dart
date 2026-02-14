import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/entities/call_entity.dart';
import '../../../chat/data/repositories/chat_repository.dart';

// Events
abstract class CallEvent {}

class StartCallEvent extends CallEvent {
  final String receiverId;
  final String type;
  StartCallEvent(this.receiverId, this.type);
}

class IncomingCallEvent extends CallEvent {
  final CallEntity call;
  IncomingCallEvent(this.call);
}

class AcceptCallEvent extends CallEvent {}

class EndCallEvent extends CallEvent {}

class CallUpdatedEvent extends CallEvent {
  final String status;
  CallUpdatedEvent(this.status);
}

// States
abstract class CallState {}

class CallIdle extends CallState {}

class CallRinging extends CallState {
  final CallEntity call;
  final bool isIncoming;
  CallRinging(this.call, {this.isIncoming = false});
}

class CallActive extends CallState {
  final String channelId;
  final RtcEngine engine;
  final int? remoteUid; // ID of the other person in the call
  final bool isRemoteUserJoined;
  final CallEntity call; // Add call entity to access type and user info

  CallActive(this.channelId, this.engine, this.call,
      {this.remoteUid, this.isRemoteUserJoined = false});
}

class CallEndedState extends CallState {}

class CallBloc extends Bloc<CallEvent, CallState> {
  final ChatRepository repository;
  StreamSubscription? _callSubscription;
  RtcEngine? _engine;
  CallEntity? _currentCall;
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _callStartTime;

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
        // 0. Request Permissions First
        await [Permission.camera, Permission.microphone].request();

        // 1. Request Call API
        final call = await repository.requestCall(event.receiverId, event.type);
        _currentCall = call;

        // 2. Initialize Agora Immediately for Local Preview
        // Init engine so we can pass it to CallScreen.
        final isVideo = event.type == 'video';
        await _initializeAgora(call.channelId!, isVideo: isVideo);

        // Play dialing sound
        await _playRingingSound();

        // Emit CallActive
        emit(CallActive(call.channelId!, _engine!, call,
            isRemoteUserJoined: false));
      } catch (e) {
        debugPrint("Start Call Error: $e");
        emit(CallEndedState());
      }
    });

    on<IncomingCallEvent>((event, emit) async {
      _currentCall = event.call;
      // Play incoming ringtone
      await _playRingingSound();
      // Show "Accept/Decline" UI
      emit(CallRinging(event.call, isIncoming: true));
    });

    on<AcceptCallEvent>((event, emit) async {
      if (_currentCall != null) {
        try {
          // Stop ringing
          await _audioPlayer.stop();

          // 1. Notify server we accepted
          await repository.acceptCall(_currentCall!.callId);
          // 2. Join Agora
          final isVideo = _currentCall!.type == 'video';
          await _initializeAgora(_currentCall!.channelId!, isVideo: isVideo);

          _callStartTime = DateTime.now();

          // Emit active state
          emit(CallActive(_currentCall!.channelId!, _engine!, _currentCall!));
        } catch (e) {
          debugPrint("Accept Call Error: $e");
          emit(CallEndedState());
        }
      }
    });

    on<CallUpdatedEvent>((event, emit) async {
      if (event.status == 'accepted' && state is CallRinging) {
        // Stop dialing sound
        await _audioPlayer.stop();

        // Use the callId we started with
        // Join channel for outgoing call accepted
        final isVideo = _currentCall!.type == 'video';
        await _initializeAgora(_currentCall!.channelId!, isVideo: isVideo);

        _callStartTime = DateTime.now();

        emit(CallActive(_currentCall!.channelId!, _engine!, _currentCall!));
      }
    });

    on<RemoteUserJoinedEvent>((event, emit) {
      if (state is CallActive) {
        final currentState = state as CallActive;
        emit(CallActive(
          currentState.channelId,
          currentState.engine,
          currentState.call,
          remoteUid: event.remoteUid,
          isRemoteUserJoined: true,
        ));
      }
    });

    on<RemoteUserLeftEvent>((event, emit) {
      if (state is CallActive) {
        final currentState = state as CallActive;
        emit(CallActive(
          currentState.channelId,
          currentState.engine,
          currentState.call,
          remoteUid: null,
          isRemoteUserJoined: false,
        ));
      }
    });

    on<EndCallEvent>((event, emit) async {
      await _audioPlayer.stop();
      int duration = 0;
      if (_callStartTime != null) {
        duration = DateTime.now().difference(_callStartTime!).inSeconds;
      }

      if (_currentCall != null) {
        repository.endCall(_currentCall!.callId, duration: duration);
      }
      _engine?.leaveChannel();
      _engine?.release();
      _engine = null;
      _currentCall = null;
      _callStartTime = null;
      emit(CallEndedState());
      await Future.delayed(const Duration(seconds: 1)); // Delay to show "Ended"
      emit(CallIdle());
    });
  }

  Future<void> _playRingingSound() async {
    try {
      // Using a better ringing sound
      await _audioPlayer.setSourceUrl(
          "https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3");
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  Future<void> _initializeAgora(String channelId, {bool isVideo = true}) async {
    if (isVideo) {
      await [Permission.camera, Permission.microphone].request();
    } else {
      await Permission.microphone.request();
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: appId));

    // Enable/Disable Video based on call type
    if (isVideo) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
      await _engine!.disableVideo(); // Ensure video is disabled for audio calls
    }

    // Event Handlers
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          // Update state with remote UID
          if (state is CallActive) {
            // We need to emit a new state to trigger UI rebuild
            // But we can't emit directly here (async/outside bloc handler scope issue?)
            // Actually, we should probably add an event for this, OR use a ValueNotifier if we want purely inside Bloc.
            // But since we are inside the Bloc class, we might try to emit?
            // Wait, we can't emit from here easily without a proper event.
            // Let's add a `RemoteUserJoinedEvent`!
            // But for simplicity/speed, let's just cheat? No, use correct pattern.
            // Or better: Just hold the remoteUid in a variable and assume the UI rebuilds?
            // No, Bloc needs an event.
            // Implementing `RemoteUserJoinedEvent` is cleaner.
            // But I can't change the events right now without multi-step.
            // Let's try to pass a callback or just use a Stream/Subject?
            // Actually, let's hack it: `emit` IS available if I use `emit` closure... but I'm in a helper method.
            // Best valid approach: Add `RemoteUserJoinedEvent`.

            // For now, I'll add the event to the stream directly if `emit` isn't accessible.
            // But I'm inside the class. I can `add(RemoteUserJoinedEvent(remoteUid))`.
            add(RemoteUserJoinedEvent(remoteUid));
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left");
          add(RemoteUserLeftEvent());
        },
      ),
    );

    // Video enable/preview moved to above condition
    await _engine!.joinChannel(
      token: "", // Testing Mode
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  Future<void> close() {
    _audioPlayer.dispose();
    _callSubscription?.cancel();
    return super.close();
  }
}

// Additional Events for Agora Sync
class RemoteUserJoinedEvent extends CallEvent {
  final int remoteUid;
  RemoteUserJoinedEvent(this.remoteUid);
}

class RemoteUserLeftEvent extends CallEvent {}
