import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/upload_repository.dart';

// Events
abstract class UploadEvent {}
class SubmitPost extends UploadEvent {
  final List<File> files;
  final String caption;
  SubmitPost(this.files, this.caption);
}

// States
abstract class UploadState {}
class UploadInitial extends UploadState {}
class Uploading extends UploadState {}
class UploadSuccess extends UploadState {}
class UploadFailure extends UploadState { final String error; UploadFailure(this.error); }

class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final UploadRepository repository;

  UploadBloc(this.repository) : super(UploadInitial()) {
    on<SubmitPost>((event, emit) async {
      emit(Uploading());
      try {
        await repository.uploadPost(files: event.files, caption: event.caption);
        emit(UploadSuccess());
      } catch (e) {
        emit(UploadFailure("Failed to upload post: ${e.toString()}"));
      }
    });
  }
}







