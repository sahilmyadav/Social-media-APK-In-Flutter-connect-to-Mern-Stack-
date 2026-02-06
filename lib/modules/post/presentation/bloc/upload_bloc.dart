import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/upload_repository.dart';

// Events
abstract class UploadEvent {}

class SubmitPost extends UploadEvent {
  final List<File> files;
  final String caption;
  final List<String>? tags;
  final String? location;
  final String visibility;

  SubmitPost({
    required this.files,
    required this.caption,
    this.tags,
    this.location,
    this.visibility = 'public',
  });
}

class SubmitReel extends UploadEvent {
  final File video;
  final String? caption;
  final String? audioId;
  final List<String>? tags;

  SubmitReel({
    required this.video,
    this.caption,
    this.audioId,
    this.tags,
  });
}

class SubmitStory extends UploadEvent {
  final File file;
  final String? caption;
  final int? duration;

  SubmitStory({
    required this.file,
    this.caption,
    this.duration,
  });
}

class SearchUsersEvent extends UploadEvent {
  final String query;
  SearchUsersEvent(this.query);
}

class SearchSongsEvent extends UploadEvent {
  final String query;
  SearchSongsEvent(this.query);
}

class ClearSearchEvent extends UploadEvent {}

// States
abstract class UploadState {}

class UploadInitial extends UploadState {}
class Uploading extends UploadState {}
class UploadSuccess extends UploadState {}
class UploadFailure extends UploadState { final String error; UploadFailure(this.error); }

class UploadSearchState extends UploadState {
  final List<Map<String, dynamic>> users;
  UploadSearchState(this.users);
}

class UploadSongSearchState extends UploadState {
  final List<Map<String, dynamic>> songs;
  UploadSongSearchState(this.songs);
}

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final UploadRepository repository;

  UploadBloc(this.repository) : super(UploadInitial()) {

    // Post Handler
    on<SubmitPost>((event, emit) async {
      emit(Uploading());
      try {
        await repository.uploadPost(
          files: event.files,
          caption: event.caption,
          tags: event.tags,
          location: event.location,
          visibility: event.visibility,
        );
        emit(UploadSuccess());
      } catch (e) {
        emit(UploadFailure("Post Failed: ${e.toString()}"));
      }
    });

    // Reel Handler
    on<SubmitReel>((event, emit) async {
      emit(Uploading());
      try {
        await repository.uploadReel(
          videoFile: event.video,
          caption: event.caption,
          audioId: event.audioId,
          tags: event.tags,
        );
        emit(UploadSuccess());
      } catch (e) {
        emit(UploadFailure("Reel Failed: ${e.toString()}"));
      }
    });

    // Story Handler
    on<SubmitStory>((event, emit) async {
      emit(Uploading());
      try {
        await repository.uploadStory(
          file: event.file,
          caption: event.caption,
          duration: event.duration,
        );
        emit(UploadSuccess());
      } catch (e) {
        emit(UploadFailure("Story Failed: ${e.toString()}"));
      }
    });

    // User Search Handler
    on<SearchUsersEvent>((event, emit) async {
      try {
        final users = await repository.searchUsers(event.query);
        emit(UploadSearchState(users));
      } catch (e) {
        emit(UploadSearchState([]));
      }
    });

    // Song Search Handler
    on<SearchSongsEvent>((event, emit) async {
      try {
        final songs = await repository.searchSongs(event.query);
        emit(UploadSongSearchState(songs));
      } catch (e) {
        emit(UploadSongSearchState([]));
      }
    });

    on<ClearSearchEvent>((event, emit) {
      emit(UploadInitial());
    });
  }
}