import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/repositories/live_repository.dart';
import '../../domain/entities/live_stream_entity.dart';

// Events
abstract class LiveEvent {}
class CreateStreamEvent extends LiveEvent { final String title; CreateStreamEvent(this.title); }
class JoinStreamEvent extends LiveEvent { final String streamId; JoinStreamEvent(this.streamId); }
class EndStreamEvent extends LiveEvent {}
class ToggleCameraEvent extends LiveEvent {}
class ToggleMuteEvent extends LiveEvent {}

// States
abstract class LiveState {}
class LiveInitial extends LiveState {}
class LiveLoading extends LiveState {}
class LiveReady extends LiveState {
  final RtcEngine engine;
  final LiveStreamEntity stream;
  final bool isBroadcaster;
  LiveReady({required this.engine, required this.stream, required this.isBroadcaster});
}
class LiveEnded extends LiveState {}
class LiveError extends LiveState { final String message; LiveError(this.message); }

class LiveBloc extends Bloc<LiveEvent, LiveState> {
  final LiveRepository repository;
  RtcEngine? _engine;

  // REPLACE THIS WITH YOUR AGORA APP ID
  static const String appId = "Ydf22818f826f47ea95b385abe6f87b42";

  LiveBloc(this.repository) : super(LiveInitial()) {

    on<CreateStreamEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        await [Permission.camera, Permission.microphone].request();

        // 1. Create Stream on Backend
        final stream = await repository.createLiveStream(event.title);

        // 2. Initialize Agora
        _engine = createAgoraRtcEngine();
        await _engine!.initialize(const RtcEngineContext(appId: appId));
        await _engine!.enableVideo();
        await _engine!.startPreview();

        // 3. Set Channel Profile to Live Broadcasting
        await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
        await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

        // 4. Join Channel
        await _engine!.joinChannel(
          token: stream.token.isNotEmpty ? stream.token : "", // Use token if API provides
          channelId: stream.channelId,
          uid: 0,
          options: const ChannelMediaOptions(),
        );

        // 5. Notify Backend Stream Started
        await repository.startLiveStream(stream.id);

        emit(LiveReady(engine: _engine!, stream: stream, isBroadcaster: true));
      } catch (e) {
        emit(LiveError("Failed to start live: $e"));
      }
    });

    on<JoinStreamEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        final stream = await repository.joinLiveStream(event.streamId);

        _engine = createAgoraRtcEngine();
        await _engine!.initialize(const RtcEngineContext(appId: appId));
        await _engine!.enableVideo();

        await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

        await _engine!.joinChannel(
          token: stream.token.isNotEmpty ? stream.token : "",
          channelId: stream.channelId,
          uid: 0,
          options: const ChannelMediaOptions(),
        );

        emit(LiveReady(engine: _engine!, stream: stream, isBroadcaster: false));
      } catch (e) {
        emit(LiveError("Failed to join stream: $e"));
      }
    });

    on<EndStreamEvent>((event, emit) async {
      if (state is LiveReady) {
        final streamId = (state as LiveReady).stream.id;
        await _engine?.leaveChannel();
        await _engine?.release();
        if ((state as LiveReady).isBroadcaster) {
          await repository.endLiveStream(streamId);
        } else {
          await repository.leaveLiveStream(streamId);
        }
        emit(LiveEnded());
      }
    });

    on<ToggleCameraEvent>((event, emit) async {
      await _engine?.switchCamera();
    });

    on<ToggleMuteEvent>((event, emit) async {
      // Implementation for mute toggle
    });
  }
}