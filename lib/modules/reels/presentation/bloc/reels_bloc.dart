import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/reels_repository.dart';
import '../../domain/entities/reel_entity.dart';

abstract class ReelsEvent {}
class FetchReels extends ReelsEvent {}
class LikeReelEvent extends ReelsEvent { final String reelId; LikeReelEvent(this.reelId); }
class SaveReelEvent extends ReelsEvent { final String reelId; SaveReelEvent(this.reelId); }
class ToggleFollowReelUserEvent extends ReelsEvent { final String userId; ToggleFollowReelUserEvent(this.userId); }

abstract class ReelsState {}
class ReelsInitial extends ReelsState {}
class ReelsLoading extends ReelsState {}
class ReelsLoaded extends ReelsState { final List<ReelEntity> reels; ReelsLoaded(this.reels); }
class ReelsError extends ReelsState { final String message; ReelsError(this.message); }

class ReelsBloc extends Bloc<ReelsEvent, ReelsState> {
  final ReelsRepository repository;

  ReelsBloc(this.repository) : super(ReelsInitial()) {

    on<FetchReels>((event, emit) async {
      if (state is ReelsInitial) emit(ReelsLoading());
      try {
        final reels = await repository.getReelsFeed();
        emit(ReelsLoaded(reels));
      } catch (e) {
        // If repository fails but returns cache, it might throw.
        // But since we handled cache in Repo fallback, here we just catch fatal errors
        emit(ReelsError("Failed to load reels: $e"));
      }
    });

    on<LikeReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentReels = (state as ReelsLoaded).reels;
        final index = currentReels.indexWhere((r) => r.id == event.reelId);
        if (index == -1) return;

        final reel = currentReels[index];
        // Optimistic Update
        final updatedReel = reel.copyWith(
          isLiked: !reel.isLiked,
          likesCount: reel.isLiked ? reel.likesCount - 1 : reel.likesCount + 1,
        );

        final updatedList = List<ReelEntity>.from(currentReels)..[index] = updatedReel;
        emit(ReelsLoaded(updatedList));

        // Update Cache immediately
        repository.updateReelInCache(updatedReel);

        try {
          await repository.toggleLikeReel(event.reelId);
        } catch (e) {
          // Revert on failure
          final revertedList = List<ReelEntity>.from(currentReels)..[index] = reel;
          emit(ReelsLoaded(revertedList));
          repository.updateReelInCache(reel); // Revert cache
        }
      }
    });

    on<SaveReelEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentReels = (state as ReelsLoaded).reels;
        final index = currentReels.indexWhere((r) => r.id == event.reelId);
        if (index == -1) return;

        final reel = currentReels[index];
        final wasSaved = reel.isSaved;

        // Optimistic Update
        final updatedReel = reel.copyWith(isSaved: !wasSaved);
        final updatedList = List<ReelEntity>.from(currentReels)..[index] = updatedReel;
        emit(ReelsLoaded(updatedList));

        // Update Cache immediately
        repository.updateReelInCache(updatedReel);

        try {
          if (wasSaved) {
            await repository.unsaveReel(event.reelId);
          } else {
            await repository.saveReel(event.reelId);
          }
        } catch (e) {
          // If server says "Already Saved" (400), do NOT revert our optimistic update
          if (!wasSaved && e is DioException && e.response?.statusCode == 400) {
            return;
          }
          // Otherwise, revert
          final revertedList = List<ReelEntity>.from(currentReels)..[index] = reel;
          emit(ReelsLoaded(revertedList));
          repository.updateReelInCache(reel); // Revert cache
        }
      }
    });

    on<ToggleFollowReelUserEvent>((event, emit) async {
      if (state is ReelsLoaded) {
        final currentReels = (state as ReelsLoaded).reels;
        final updatedList = currentReels.map((reel) {
          if (reel.user.id == event.userId) {
            return reel.copyWith(isFollowing: !reel.isFollowing);
          }
          return reel;
        }).toList();

        emit(ReelsLoaded(updatedList));
        // We could also update cache for all reels by this user,
        // but it's expensive to iterate entire cache for one follow.
        // Ideally, user follow status is stored in a separate UserBox.

        try {
          final isFollowingNow = updatedList.firstWhere((r) => r.user.id == event.userId).isFollowing;
          if (isFollowingNow) {
            await repository.followUser(event.userId);
          } else {
            await repository.unfollowUser(event.userId);
          }
        } catch (e) {
          // Revert logic
        }
      }
    });
  }
}