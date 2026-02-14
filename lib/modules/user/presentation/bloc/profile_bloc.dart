import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../feed/domain/entities/post_entity.dart'; // Ensure this path matches
import '../../../reels/domain/entities/reel_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

// Events
abstract class ProfileEvent {}

class FetchProfile extends ProfileEvent {
  final String userId;
  FetchProfile(this.userId);
}

class RefreshProfile extends ProfileEvent {
  final String userId;
  RefreshProfile(this.userId);
}

class ToggleFollowEvent extends ProfileEvent {
  final String userId;
  ToggleFollowEvent(this.userId);
}

class BlockUserEvent extends ProfileEvent {
  final String userId;
  BlockUserEvent(this.userId);
}

class UnblockUserEvent extends ProfileEvent {
  final String userId;
  UnblockUserEvent(this.userId);
}

class ReportUserEvent extends ProfileEvent {
  final String userId;
  final String reason;
  ReportUserEvent(this.userId, this.reason);
}

class UpdateProfileEvent extends ProfileEvent {
  final String? bio;
  final File? image;
  UpdateProfileEvent({this.bio, this.image});
}

// States
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserEntity user;
  final bool isMe;
  final List<PostEntity> posts;
  final List<ReelEntity> reels;
  final List<PostEntity> savedPosts; // Added
  final List<ReelEntity> savedReels; // Added

  ProfileLoaded(
    this.user, {
    this.isMe = false,
    this.posts = const [],
    this.reels = const [],
    this.savedPosts = const [],
    this.savedReels = const [],
  });

  ProfileLoaded copyWith({
    UserEntity? user,
    bool? isMe,
    List<PostEntity>? posts,
    List<ReelEntity>? reels,
    List<PostEntity>? savedPosts,
    List<ReelEntity>? savedReels,
  }) {
    return ProfileLoaded(
      user ?? this.user,
      isMe: isMe ?? this.isMe,
      posts: posts ?? this.posts,
      reels: reels ?? this.reels,
      savedPosts: savedPosts ?? this.savedPosts,
      savedReels: savedReels ?? this.savedReels,
    );
  }
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;

  ProfileBloc(this.repository) : super(ProfileInitial()) {
    on<FetchProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final cachedUser = await repository.getCachedUserProfile(event.userId);
        if (cachedUser != null) {
          emit(ProfileLoaded(cachedUser));
        }

        // 1. Fetch Profile First
        final user = await repository.getRemoteUserProfile(event.userId);
        UserEntity? myProfile;

        // Determine if "isMe"
        bool isMe = event.userId == "me";
        if (!isMe) {
          try {
            myProfile = await repository.getMyProfile();
            isMe = myProfile.id == user.id;
          } catch (_) {
            // Ignore error if can't fetch my profile
          }
        }

        List<PostEntity> posts = [];
        List<ReelEntity> reels = [];
        List<PostEntity> savedPosts = [];
        List<ReelEntity> savedReels = [];

        // 2. Only fetch posts and reels if NOT blocked
        if (!user.isBlocked) {
          final futures = <Future>[
            repository.getUserPosts(user.id), // Use resolved user.id
            repository.getUserReels(user.id),
          ];

          if (isMe) {
            futures.add(repository.getSavedPosts());
            futures.add(repository.getSavedReels());
          }

          final results = await Future.wait(futures);

          posts = results[0] as List<PostEntity>;
          reels = results[1] as List<ReelEntity>;

          if (isMe && results.length > 2) {
            savedPosts = results[2] as List<PostEntity>;
            savedReels = results[3] as List<ReelEntity>;
          }
        }

        emit(ProfileLoaded(
          user,
          isMe: isMe,
          posts: posts,
          reels: reels,
          savedPosts: savedPosts,
          savedReels: savedReels,
        ));
      } catch (e) {
        if (state is! ProfileLoaded) {
          emit(ProfileError("Failed to load profile or user not found"));
        }
      }
    });

    on<RefreshProfile>((event, emit) async {
      try {
        final user = await repository.getRemoteUserProfile(event.userId);
        UserEntity? myProfile;

        // Determine if "isMe"
        bool isMe = event.userId == "me";
        if (!isMe) {
          try {
            myProfile = await repository.getMyProfile();
            isMe = myProfile.id == user.id;
          } catch (_) {}
        }

        List<PostEntity> posts = [];
        List<ReelEntity> reels = [];
        List<PostEntity> savedPosts = [];
        List<ReelEntity> savedReels = [];

        if (!user.isBlocked) {
          final futures = <Future>[
            repository.getUserPosts(user.id),
            repository.getUserReels(user.id),
          ];

          if (isMe) {
            futures.add(repository.getSavedPosts());
            futures.add(repository.getSavedReels());
          }

          final results = await Future.wait(futures);
          posts = results[0] as List<PostEntity>;
          reels = results[1] as List<ReelEntity>;

          if (isMe && results.length > 2) {
            savedPosts = results[2] as List<PostEntity>;
            savedReels = results[3] as List<ReelEntity>;
          }
        }

        emit(ProfileLoaded(
          user,
          isMe: isMe,
          posts: posts,
          reels: reels,
          savedPosts: savedPosts,
          savedReels: savedReels,
        ));
      } catch (_) {}
    });

    on<ToggleFollowEvent>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        // Prevent following if blocked
        if (currentState.user.isBlocked) return;

        final bool originalStatus = currentState.user.isFollowing;
        final int originalCount = currentState.user.followersCount;

        final updatedUser = currentState.user.copyWith(
          isFollowing: !originalStatus,
          followersCount:
              originalStatus ? originalCount - 1 : originalCount + 1,
        );

        emit(currentState.copyWith(user: updatedUser));

        try {
          if (originalStatus) {
            await repository.unfollowUser(event.userId);
          } else {
            await repository.followUser(event.userId);
          }
        } catch (e) {
          emit(currentState.copyWith(user: currentState.user));
        }
      }
    });

    on<BlockUserEvent>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        // Optimistic UI: Mark as blocked immediately and clear posts/reels
        emit(currentState.copyWith(
            user:
                currentState.user.copyWith(isBlocked: true, isFollowing: false),
            posts: [], // Clear posts immediately
            reels: [] // Clear reels immediately
            ));
        try {
          await repository.blockUser(event.userId);
        } catch (e) {
          // Revert if failed
          emit(currentState.copyWith(
              user: currentState.user.copyWith(isBlocked: false)));
        }
      }
    });

    on<UnblockUserEvent>((event, emit) async {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        // Optimistic UI: Mark as unblocked immediately
        emit(currentState.copyWith(
            user: currentState.user.copyWith(isBlocked: false)));
        try {
          await repository.unblockUser(event.userId);
          // Trigger refresh to get posts and reels back
          add(RefreshProfile(event.userId));
        } catch (e) {
          // Revert if failed
          emit(currentState.copyWith(
              user: currentState.user.copyWith(isBlocked: true)));
        }
      }
    });

    on<ReportUserEvent>((event, emit) async {
      try {
        await repository.reportUser(event.userId, event.reason);
      } catch (e) {
        // Handled silently
      }
    });
  }
}
