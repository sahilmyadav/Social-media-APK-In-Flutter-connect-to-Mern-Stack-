import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/story_repository.dart';
import '../../domain/entities/story_entity.dart';

// Events
abstract class StoryEvent {}
class FetchStories extends StoryEvent {}
class ViewStoryEvent extends StoryEvent { final String storyId; ViewStoryEvent(this.storyId); }
class UploadStoryEvent extends StoryEvent { final File file; UploadStoryEvent(this.file); }

// States
abstract class StoryState {}
class StoryInitial extends StoryState {}
class StoryLoading extends StoryState {}
class StoryLoaded extends StoryState { final List<StoryFeedEntity> feed; StoryLoaded(this.feed); }
class StoryUploadSuccess extends StoryState {}
class StoryError extends StoryState { final String message; StoryError(this.message); }

class StoryBloc extends Bloc<StoryEvent, StoryState> {
  final StoryRepository repository;

  StoryBloc(this.repository) : super(StoryInitial()) {
    on<FetchStories>((event, emit) async {
      emit(StoryLoading());
      try {
        final stories = await repository.getStoryFeed();
        emit(StoryLoaded(stories));
      } catch (e) {
        emit(StoryError("Failed to load stories"));
      }
    });

    on<ViewStoryEvent>((event, emit) async {
      await repository.markStoryViewed(event.storyId);
      // We don't reload feed here to avoid UI jump, just silent update
    });

    on<UploadStoryEvent>((event, emit) async {
      try {
        await repository.uploadStory(event.file);
        emit(StoryUploadSuccess());
        add(FetchStories()); // Refresh feed
      } catch (e) {
        emit(StoryError("Failed to upload story"));
      }
    });
  }
}