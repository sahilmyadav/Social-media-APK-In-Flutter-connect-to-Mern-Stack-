import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/story_repository.dart';
import '../../domain/entities/story_entity.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

// Events
abstract class StoryEvent {}

class FetchStories extends StoryEvent {}

class FetchMyStories extends StoryEvent {
  final String userId;
  FetchMyStories(this.userId);
}

class ViewStoryEvent extends StoryEvent {
  final String storyId;
  ViewStoryEvent(this.storyId);
}

class UploadStoryEvent extends StoryEvent {
  final File file;
  final String caption;
  final String type;
  final int duration;
  UploadStoryEvent(this.file,
      {this.caption = '', this.type = 'image', this.duration = 5});
}

class DeleteStoryEvent extends StoryEvent {
  final String storyId;
  DeleteStoryEvent(this.storyId);
}

class DeleteAllStoriesEvent extends StoryEvent {}

class FetchStoryViewersEvent extends StoryEvent {
  final String storyId;
  FetchStoryViewersEvent(this.storyId);
}

// States
abstract class StoryState {}

class StoryInitial extends StoryState {}

class StoryLoading extends StoryState {}

class StoryLoaded extends StoryState {
  final List<StoryFeedEntity> feed;
  final List<StoryItemEntity> myStories;
  StoryLoaded(this.feed, {this.myStories = const []});
}

class StoryUploadSuccess extends StoryState {}

class StoryError extends StoryState {
  final String message;
  StoryError(this.message);
}

class StoryViewersLoaded extends StoryState {
  final List<UserEntity> viewers;
  StoryViewersLoaded(this.viewers);
}

class StoryBloc extends Bloc<StoryEvent, StoryState> {
  final StoryRepository repository;

  StoryBloc(this.repository) : super(StoryInitial()) {
    on<FetchStories>((event, emit) async {
      List<StoryItemEntity> currentMyStories = [];
      if (state is StoryLoaded) {
        currentMyStories = (state as StoryLoaded).myStories;
      } else {
        emit(StoryLoading());
      }

      try {
        final stories = await repository.getStoryFeed();
        emit(StoryLoaded(stories, myStories: currentMyStories));
      } catch (e) {
        // If we have myStories, we might want to keep showing them?
        // For now, simpler error handling or fallback
        if (currentMyStories.isNotEmpty) {
          emit(StoryLoaded([],
              myStories:
                  currentMyStories)); // Show empty feed but keep my stories?
        } else {
          emit(StoryError("Failed to load stories"));
        }
      }
    });

    on<FetchMyStories>((event, emit) async {
      List<StoryFeedEntity> currentFeed = [];
      if (state is StoryLoaded) {
        currentFeed = (state as StoryLoaded).feed;
      }

      try {
        final myStories = await repository.getUserStories(event.userId);
        emit(StoryLoaded(currentFeed, myStories: myStories));
      } catch (e) {
        debugPrint("Failed to fetch my stories: $e");
        if (state is StoryLoaded) {
          // emit same state to notify listeners if needed, or just do nothing
          // For now, do nothing as we don't want to break the UI
        }
      }
    });

    on<ViewStoryEvent>((event, emit) async {
      // OLD CODE:
      // await repository.markStoryViewed(event.storyId);
      // // Silent update

      // NEW CODE:
      try {
        await repository.markStoryViewed(event.storyId);

        if (state is StoryLoaded) {
          final currentState = state as StoryLoaded;
          // 1. Update the specific story in the feed as 'viewed'
          // We need to find which user this story belongs to
          final updatedFeed = currentState.feed.map((userStory) {
            final storyIndex =
                userStory.stories.indexWhere((s) => s.id == event.storyId);

            if (storyIndex != -1) {
              // Found the user and the story
              final updatedStories =
                  List<StoryItemEntity>.from(userStory.stories);
              final oldStory = updatedStories[storyIndex];

              // Mark as viewed
              updatedStories[storyIndex] = StoryItemEntity(
                id: oldStory.id,
                mediaUrl: oldStory.mediaUrl,
                mediaType: oldStory.mediaType,
                caption: oldStory.caption,
                hasViewed: true, // Mark as viewed
                viewsCount: oldStory.viewsCount,
                duration: oldStory.duration,
                createdAt: oldStory.createdAt,
              );

              // Check if all stories for this user are now viewed
              final hasUnseen = updatedStories.any((s) => !s.hasViewed);

              return StoryFeedEntity(
                user: userStory.user,
                stories: updatedStories,
                hasUnseen: hasUnseen,
              );
            }
            return userStory;
          }).toList();

          // 2. Sort the feed: Unseen first, then Seen
          updatedFeed.sort((a, b) {
            if (a.hasUnseen && !b.hasUnseen) return -1;
            if (!a.hasUnseen && b.hasUnseen) return 1;
            return 0; // Maintain original order otherwise
          });

          emit(StoryLoaded(updatedFeed, myStories: currentState.myStories));
        }
      } catch (e) {
        debugPrint("Error marking story as viewed: $e");
      }
    });

    on<UploadStoryEvent>((event, emit) async {
      try {
        await repository.uploadStory(event.file,
            caption: event.caption, duration: event.duration);
        emit(StoryUploadSuccess());
        add(FetchStories()); // Refresh feed
        // We can't refresh my stories here easily without userId.
        // It will be refreshed on next load or if we pass userId to UploadStoryEvent?
        // Ideally we should refresh my stories too.
      } catch (e) {
        emit(StoryError("Failed to upload story"));
      }
    });

    on<DeleteStoryEvent>((event, emit) async {
      try {
        await repository.deleteStory(event.storyId);
        // Optimistic update of myStories
        if (state is StoryLoaded) {
          final current = state as StoryLoaded;
          final updatedMyStories =
              current.myStories.where((s) => s.id != event.storyId).toList();
          emit(StoryLoaded(current.feed, myStories: updatedMyStories));
        }
        add(FetchStories()); // Refresh feed
      } catch (e) {
        emit(StoryError("Failed to delete story"));
      }
    });

    on<DeleteAllStoriesEvent>((event, emit) async {
      if (state is StoryLoaded) {
        final currentStories = (state as StoryLoaded).myStories;
        for (var story in currentStories) {
          try {
            await repository.deleteStory(story.id);
          } catch (e) {
            debugPrint("Failed to delete story ${story.id}: $e");
          }
        }
        // Optimistic clear of myStories
        emit(StoryLoaded((state as StoryLoaded).feed, myStories: []));
        add(FetchStories());
      }
    });

    on<FetchStoryViewersEvent>((event, emit) async {
      try {
        final viewers = await repository.getStoryViewers(event.storyId);
        emit(StoryViewersLoaded(viewers));
      } catch (e) {
        emit(StoryError("Failed to load viewers"));
      }
    });
  }
}
