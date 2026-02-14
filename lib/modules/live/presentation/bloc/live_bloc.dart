import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import '../../data/repositories/live_repository.dart';
import '../../domain/entities/live_stream_entity.dart';

import 'dart:async';

// Events
abstract class LiveEvent {}

class CreateStreamEvent extends LiveEvent {
  final String title;
  final String description;
  final String? thumbnailPath;
  CreateStreamEvent(
      {required this.title, required this.description, this.thumbnailPath});
}

class StartBroadcastingEvent extends LiveEvent {
  final LiveStreamEntity stream;
  StartBroadcastingEvent(this.stream);
}

class JoinStreamEvent extends LiveEvent {
  final String streamId;
  JoinStreamEvent(this.streamId);
}

class EndStreamEvent extends LiveEvent {}

class LeaveStreamEvent extends LiveEvent {}

class ToggleCameraEvent extends LiveEvent {}

class ToggleMuteEvent extends LiveEvent {}

class SendCommentEvent extends LiveEvent {
  final String streamId;
  final String content;
  SendCommentEvent(this.streamId, this.content);
}

class LoadCommentsEvent extends LiveEvent {
  final String streamId;
  LoadCommentsEvent(this.streamId);
}

class FetchStreamUpdatesEvent extends LiveEvent {
  final String streamId;
  FetchStreamUpdatesEvent(this.streamId);
}

// Feed Events
class FetchAllStreamsEvent extends LiveEvent {}

// Internal Events
class BroadcasterJoinedEvent extends LiveEvent {
  final int uid;
  BroadcasterJoinedEvent(this.uid);
}

class BroadcasterLeftEvent extends LiveEvent {}

// States
abstract class LiveState {}

class LiveInitial extends LiveState {}

class LiveLoading extends LiveState {}

class LiveStreamCreated extends LiveState {
  final LiveStreamEntity stream;
  LiveStreamCreated(this.stream);
}

class LiveBroadcasting extends LiveState {
  final RtcEngine engine;
  final LiveStreamEntity stream;
  final List<dynamic> comments;
  LiveBroadcasting(
      {required this.engine, required this.stream, this.comments = const []});
}

class LiveWatching extends LiveState {
  final RtcEngine engine;
  final LiveStreamEntity stream;
  final List<dynamic> comments;
  final int? remoteUid; // Added to track broadcaster
  LiveWatching(
      {required this.engine,
      required this.stream,
      this.comments = const [],
      this.remoteUid});
}

class LiveFeedLoaded extends LiveState {
  final List<LiveStreamEntity> streams;
  LiveFeedLoaded(this.streams);
}

class LiveEnded extends LiveState {}

class LiveError extends LiveState {
  final String message;
  LiveError(this.message);
}

class LiveBloc extends Bloc<LiveEvent, LiveState> {
  final LiveRepository repository;
  RtcEngine? _engine;

  // REPLACE THIS WITH YOUR AGORA APP ID
  static const String appId = "df22818f826f47ea95b385abe6f87b42";

  LiveBloc(this.repository) : super(LiveInitial()) {
    on<FetchAllStreamsEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        final streams = await repository.getAllStreams();
        emit(LiveFeedLoaded(streams));
      } catch (e) {
        emit(LiveError("Failed to fetch streams"));
      }
    });

    on<CreateStreamEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        final stream = await repository.createLiveStream(
            title: event.title,
            description: event.description,
            thumbnailPath: event.thumbnailPath);
        emit(LiveStreamCreated(stream));
      } catch (e) {
        emit(LiveError("Failed to create stream: $e"));
      }
    });

    on<StartBroadcastingEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        if (appId.isEmpty || appId.contains(' ')) {
          emit(LiveError(
              "Invalid Agora App ID: '$appId'. Please update it in LiveBloc."));
          return;
        }

        await [Permission.camera, Permission.microphone].request();

        // 1. Notify Backend
        print("Starting live stream for ID: ${event.stream.id}");
        await repository.startLiveStream(event.stream.id);

        // 2. Init Agora
        _engine = createAgoraRtcEngine();
        await _engine!.initialize(const RtcEngineContext(appId: appId));
        await _engine!.enableVideo();
        await _engine!.startPreview();
        await _engine!.setChannelProfile(
            ChannelProfileType.channelProfileLiveBroadcasting);
        await _engine!
            .setClientRole(role: ClientRoleType.clientRoleBroadcaster);

        // 3. Join Channel (Using streamKey as channelId)
        await _engine!.joinChannel(
          token: "",
          channelId: event.stream.id,
          uid: 0,
          options: const ChannelMediaOptions(
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );

        // Register event handler for Broadcaster (to see viewer count updates or connection state)
        // For now, mainly useful for debug or connection status.
        _engine!.registerEventHandler(
          RtcEngineEventHandler(
            onError: (ErrorCodeType err, String msg) {
              debugPrint("❌ Broadcaster Agora Error: $err - $msg");
            },
            onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
              debugPrint(
                  "✅ Broadcaster joined channel: ${connection.channelId} with uid ${connection.localUid}");
            },
            onUserJoined:
                (RtcConnection connection, int remoteUid, int elapsed) {
              debugPrint("✅ User joined stream: $remoteUid");
            },
          ),
        );

        emit(LiveBroadcasting(
            engine: _engine!, stream: event.stream, comments: []));

        // Start polling
        add(FetchStreamUpdatesEvent(event.stream.id));
      } catch (e) {
        if (e.toString().contains("DioException")) {
          emit(LiveError("Failed to start broadcast (API): $e"));
        } else {
          emit(LiveError("Failed to start broadcast: $e"));
        }
      }
    });

    on<JoinStreamEvent>((event, emit) async {
      emit(LiveLoading());
      try {
        final stream = await repository.joinLiveStream(event.streamId);

        _engine = createAgoraRtcEngine();
        await _engine!.initialize(const RtcEngineContext(appId: appId));
        await _engine!.enableVideo();
        await _engine!.setChannelProfile(
            ChannelProfileType.channelProfileLiveBroadcasting);
        await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

        // Register Event Handler BEFORE joining
        _engine!.registerEventHandler(
          RtcEngineEventHandler(
            onError: (ErrorCodeType err, String msg) {
              debugPrint("❌ Agora Error: $err - $msg");
            },
            onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
              debugPrint(
                  "✅ Audience joined channel: ${connection.channelId} with uid ${connection.localUid}");
            },
            onUserJoined:
                (RtcConnection connection, int remoteUid, int elapsed) {
              debugPrint("✅ Broadcaster joined: $remoteUid");
              add(BroadcasterJoinedEvent(remoteUid));
            },
            onUserOffline: (RtcConnection connection, int remoteUid,
                UserOfflineReasonType reason) {
              debugPrint("❌ Broadcaster left: $remoteUid");
              add(BroadcasterLeftEvent());
            },
          ),
        );

        await _engine!.joinChannel(
          token: "",
          channelId: stream.id,
          uid: 0,
          options: const ChannelMediaOptions(
            autoSubscribeVideo: true,
            autoSubscribeAudio: true,
            clientRoleType: ClientRoleType.clientRoleAudience,
          ),
        );

        emit(LiveWatching(engine: _engine!, stream: stream, comments: []));

        // Start polling
        add(FetchStreamUpdatesEvent(event.streamId));
      } catch (e) {
        emit(LiveError("Failed to join stream: $e"));
      }
    });

    on<EndStreamEvent>((event, emit) async {
      _pollingTimer?.cancel();
      if (state is LiveBroadcasting) {
        final streamId = (state as LiveBroadcasting).stream.id;
        await _engine?.leaveChannel();
        await _engine?.release();
        await repository.endLiveStream(streamId);
        emit(LiveEnded());
      }
    });

    on<LeaveStreamEvent>((event, emit) async {
      _pollingTimer?.cancel();
      if (state is LiveWatching) {
        final streamId = (state as LiveWatching).stream.id;
        await _engine?.leaveChannel();
        await _engine?.release();
        await repository.leaveLiveStream(streamId);
        emit(LiveEnded());
      }
    });

    on<ToggleCameraEvent>((event, emit) async {
      await _engine?.switchCamera();
    });

    on<ToggleMuteEvent>((event, emit) async {
      // Implementation for mute toggle
    });

    on<SendCommentEvent>((event, emit) async {
      try {
        await repository.sendComment(event.streamId, event.content);
        // Instant update not needed if polling is fast enough, but good for UX
        add(LoadCommentsEvent(event.streamId));
      } catch (e) {
        print("Failed to send comment: $e");
      }
    });

    on<LoadCommentsEvent>((event, emit) async {
      try {
        final comments = await repository.getComments(event.streamId);
        if (state is LiveBroadcasting) {
          final curr = state as LiveBroadcasting;
          emit(LiveBroadcasting(
              engine: curr.engine, stream: curr.stream, comments: comments));
        } else if (state is LiveWatching) {
          final curr = state as LiveWatching;
          emit(LiveWatching(
              engine: curr.engine, stream: curr.stream, comments: comments));
        }
      } catch (e) {
        print("Failed to load comments: $e");
      }
    });

    on<BroadcasterJoinedEvent>((event, emit) {
      if (state is LiveWatching) {
        final curr = state as LiveWatching;
        emit(LiveWatching(
            engine: curr.engine,
            stream: curr.stream,
            comments: curr.comments,
            remoteUid: event.uid));
      }
    });

    on<BroadcasterLeftEvent>((event, emit) {
      if (state is LiveWatching) {
        final curr = state as LiveWatching;
        emit(LiveWatching(
            engine: curr.engine,
            stream: curr.stream,
            comments: curr.comments,
            remoteUid: null));
      }
    });

    on<FetchStreamUpdatesEvent>((event, emit) async {
      try {
        // Fetch comments
        final comments = await repository.getComments(event.streamId);

        // Fetch stream details for viewer count
        // Note: For broadcaster, we might want to keep the local stream object mostly,
        // but update viewers. For watcher, we update everything.
        // Assuming getStreamDetails returns updated viewer count.
        final updatedStream = await repository.getStreamDetails(event.streamId);

        if (state is LiveBroadcasting) {
          final curr = state as LiveBroadcasting;
          emit(LiveBroadcasting(
              engine: curr.engine,
              stream: updatedStream, // Updates viewer count
              comments: comments));
        } else if (state is LiveWatching) {
          final curr = state as LiveWatching;
          emit(LiveWatching(
              engine: curr.engine, stream: updatedStream, comments: comments));
        }

        // Schedule next poll
        _pollingTimer?.cancel();
        _pollingTimer = Timer(const Duration(seconds: 5), () {
          add(FetchStreamUpdatesEvent(event.streamId));
        });
      } catch (e) {
        print("Polling error: $e");
        // Retry poll even on error
        _pollingTimer?.cancel();
        _pollingTimer = Timer(const Duration(seconds: 5), () {
          add(FetchStreamUpdatesEvent(event.streamId));
        });
      }
    });
  }

  Timer? _pollingTimer;

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    _engine?.release();
    return super.close();
  }
}
