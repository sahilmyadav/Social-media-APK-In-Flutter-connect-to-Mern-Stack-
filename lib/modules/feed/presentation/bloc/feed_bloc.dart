import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/post_entity.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';
import '../../data/repositories/feed_repository_impl.dart';

// Events
abstract class FeedEvent {}
class LoadFeed extends FeedEvent {}
class RefreshFeed extends FeedEvent {}
class LikePostEvent extends FeedEvent { final String postId; LikePostEvent(this.postId); }
class SavePostEvent extends FeedEvent { final String postId; SavePostEvent(this.postId); }
class DeletePostEvent extends FeedEvent { final String postId; DeletePostEvent(this.postId); }
class ReportPostEvent extends FeedEvent {
  final String postId;
  final String reason;
  final String description;
  ReportPostEvent(this.postId, this.reason, this.description);
}
class UnfollowUserEvent extends FeedEvent { final String userId; UnfollowUserEvent(this.userId); }
class FollowUserFromSuggestions extends FeedEvent { final String userId; FollowUserFromSuggestions(this.userId); }

// States
abstract class FeedState {}
class FeedInitial extends FeedState {}
class FeedLoading extends FeedState {}
class FeedLoaded extends FeedState {
  final List<PostEntity> posts;
  final List<UserEntity> suggestions;
  final UserEntity? currentUser;
  FeedLoaded(this.posts, {this.suggestions = const [], this.currentUser});
}
class FeedError extends FeedState { final String message; final List<PostEntity> currentPosts; FeedError(this.message, this.currentPosts); }

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final FeedRepositoryImpl repository;

  FeedBloc(this.repository) : super(FeedInitial()) {

    on<LoadFeed>((event, emit) async {
      final cachedPosts = repository.getCachedFeed();
      if (cachedPosts.isEmpty) emit(FeedLoading());
      else emit(FeedLoaded(cachedPosts));

      try {
        final results = await Future.wait([
          repository.getRemoteFeed(),
          repository.getFollowSuggestions(),
          repository.getCurrentUser(),
        ]);

        emit(FeedLoaded(
            results[0] as List<PostEntity>,
            suggestions: results[1] as List<UserEntity>,
            currentUser: results[2] as UserEntity?
        ));
      } catch (e) {
        if (cachedPosts.isEmpty) emit(FeedError(e.toString().replaceAll("Exception: ", ""), []));
      }
    });

    on<RefreshFeed>((event, emit) async {
      try {
        final results = await Future.wait([
          repository.getRemoteFeed(),
          repository.getFollowSuggestions(),
          repository.getCurrentUser(),
        ]);
        emit(FeedLoaded(
            results[0] as List<PostEntity>,
            suggestions: results[1] as List<UserEntity>,
            currentUser: results[2] as UserEntity?
        ));
      } catch (e) {
        if (state is FeedLoaded) emit(FeedError(e.toString(), (state as FeedLoaded).posts));
      }
    });

    on<LikePostEvent>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;
        final index = currentState.posts.indexWhere((p) => p.id == event.postId);

        if (index != -1) {
          final post = currentState.posts[index];
          final updatedPost = post.copyWith(
            isLiked: !post.isLiked,
            likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
          );
          final updatedList = List<PostEntity>.from(currentState.posts)..[index] = updatedPost;
          emit(FeedLoaded(updatedList, suggestions: currentState.suggestions, currentUser: currentState.currentUser));

          try {
            if (post.isLiked) await repository.unlikePost(event.postId);
            else await repository.likePost(event.postId);
          } catch (e) {
            emit(currentState);
          }
        }
      }
    });

    on<SavePostEvent>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;
        final index = currentState.posts.indexWhere((p) => p.id == event.postId);

        if (index != -1) {
          final post = currentState.posts[index];
          final bool wasSaved = post.isSaved;
          final bool newSavedState = !wasSaved;

          // 1. Optimistic Memory Update
          final updatedPost = post.copyWith(isSaved: newSavedState);
          final updatedList = List<PostEntity>.from(currentState.posts)..[index] = updatedPost;
          emit(FeedLoaded(updatedList, suggestions: currentState.suggestions, currentUser: currentState.currentUser));

          // 2. Optimistic Cache Update (Persistence)
          repository.updatePostInCache(event.postId, isSaved: newSavedState);

          try {
            if (wasSaved) {
              await repository.unsavePost(event.postId);
            } else {
              await repository.savePost(event.postId);
            }
          } catch (e) {
            // Revert on failure
            final revertPost = post.copyWith(isSaved: wasSaved);
            final revertList = List<PostEntity>.from(currentState.posts)..[index] = revertPost;
            emit(FeedLoaded(revertList, suggestions: currentState.suggestions, currentUser: currentState.currentUser));
            repository.updatePostInCache(event.postId, isSaved: wasSaved);
          }
        }
      }
    });

    on<DeletePostEvent>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;
        final updatedList = List<PostEntity>.from(currentState.posts)..removeWhere((p) => p.id == event.postId);
        emit(FeedLoaded(updatedList, suggestions: currentState.suggestions, currentUser: currentState.currentUser));
        try {
          await repository.deletePost(event.postId);
        } catch (e) {}
      }
    });

    on<ReportPostEvent>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;
        final originalPosts = List<PostEntity>.from(currentState.posts);

        final updatedList = List<PostEntity>.from(currentState.posts)..removeWhere((p) => p.id == event.postId);
        emit(FeedLoaded(updatedList, suggestions: currentState.suggestions, currentUser: currentState.currentUser));

        try {
          await repository.reportPost(event.postId, event.reason, event.description);
        } catch (e) {
          emit(FeedLoaded(originalPosts, suggestions: currentState.suggestions, currentUser: currentState.currentUser));
        }
      }
    });

    on<UnfollowUserEvent>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;

        // 1. Update UI (Optimistic)
        final updatedPosts = currentState.posts.map((post) {
          if (post.user.id == event.userId) {
            final updatedUser = post.user.copyWith(isFollowing: false);
            return post.copyWith(user: updatedUser);
          }
          return post;
        }).toList();

        emit(FeedLoaded(updatedPosts, suggestions: currentState.suggestions, currentUser: currentState.currentUser));

        // 2. Persist to Cache (Fixes Restart Issue)
        repository.updateFollowStatusInCache(event.userId, false);

        try {
          await repository.unfollowUser(event.userId);
        } catch (e) {
          emit(currentState);
          // Revert cache if API fails
          repository.updateFollowStatusInCache(event.userId, true);
        }
      }
    });

    // ... inside FeedBloc

    on<FollowUserFromSuggestions>((event, emit) async {
      if (state is FeedLoaded) {
        final currentState = state as FeedLoaded;

        // 1. UPDATE STATE (Don't Remove)
        // Find the user and mark as following
        final updatedSuggestions = currentState.suggestions.map((user) {
          if (user.id == event.userId) {
            return user.copyWith(isFollowing: true);
          }
          return user;
        }).toList();

        // 2. Emit new state immediately (UI updates to "Following")
        emit(FeedLoaded(
            currentState.posts,
            suggestions: updatedSuggestions, // Pass updated list
            currentUser: currentState.currentUser
        ));

        // 3. API Call
        try {
          await repository.followUser(event.userId);
          // Also update cache for persistence
          repository.updateFollowStatusInCache(event.userId, true);
        } catch (e) {
          // Revert if failed
          final revertedSuggestions = currentState.suggestions.map((user) {
            if (user.id == event.userId) {
              return user.copyWith(isFollowing: false);
            }
            return user;
          }).toList();
          emit(FeedLoaded(currentState.posts, suggestions: revertedSuggestions, currentUser: currentState.currentUser));
        }
      }
    });

// ... rest of Bloc
  }
}