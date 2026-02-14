import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/local_storage/hive_helper.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/notification_entity.dart';

// Events
abstract class NotificationEvent {}

class LoadNotifications extends NotificationEvent {}

class RefreshNotifications extends NotificationEvent {}

class MarkReadEvent extends NotificationEvent {
  final String id;
  MarkReadEvent(this.id);
}

class FollowBackEvent extends NotificationEvent {
  final String userId;
  final String notificationId;
  FollowBackEvent(this.userId, this.notificationId);
}

// States
abstract class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  NotificationLoaded(this.notifications, {this.unreadCount = 0});
}

class NotificationError extends NotificationState {
  final String message;
  NotificationError(this.message);
}

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository repository;

  // Keep track of locally followed IDs to prevent reverting on API refresh

  NotificationBloc(this.repository) : super(NotificationInitial()) {
    on<LoadNotifications>((event, emit) async {
      // 1. Load Cache First
      try {
        final cachedData = HiveHelper.getCachedNotifications();
        if (cachedData.isNotEmpty) {
          final cachedList =
              cachedData.map((e) => NotificationEntity.fromJson(e)).toList();
          emit(NotificationLoaded(cachedList));
        } else {
          emit(NotificationLoading());
        }
      } catch (_) {
        emit(NotificationLoading());
      }

      // 2. Fetch Fresh Data
      try {
        final list = await repository.getNotifications();
        final count = await repository.getUnreadCount();

        // MERGE LOGIC: If we locally followed someone, enforce true on the fresh list
        final followedUsers = HiveHelper.getFollowedUsers().toSet();

        final mergedList = list.map((n) {
          if (followedUsers.contains(n.sender.id)) {
            // Check sender ID, not notification ID
            final updatedSender = n.sender.copyWith(isFollowing: true);
            return n.copyWith(isFollowedBack: true, sender: updatedSender);
          }
          return n;
        }).toList();

        emit(NotificationLoaded(mergedList, unreadCount: count));
      } catch (e) {
        if (state is! NotificationLoaded) {
          emit(NotificationError("Failed to load notifications"));
        }
      }
    });

    on<RefreshNotifications>((event, emit) async {
      try {
        final list = await repository.getNotifications();
        final count = await repository.getUnreadCount();

        // MERGE LOGIC for Refresh as well
        final followedUsers = HiveHelper.getFollowedUsers().toSet();

        final mergedList = list.map((n) {
          if (followedUsers.contains(n.sender.id)) {
            final updatedSender = n.sender.copyWith(isFollowing: true);
            return n.copyWith(isFollowedBack: true, sender: updatedSender);
          }
          return n;
        }).toList();

        emit(NotificationLoaded(mergedList, unreadCount: count));
      } catch (e) {
        // Keep current state
      }
    });

    on<FollowBackEvent>((event, emit) async {
      if (state is NotificationLoaded) {
        final currentState = state as NotificationLoaded;

        // 1. Add to local memory set & Hive
        await HiveHelper.cacheFollowedUser(event.userId);

        // 2. Optimistic Update
        final updatedList = currentState.notifications.map((n) {
          if (n.sender.id == event.userId) {
            // Update ALL notifications from this user
            final updatedSender = n.sender.copyWith(isFollowing: true);
            return n.copyWith(isFollowedBack: true, sender: updatedSender);
          }
          return n;
        }).toList();

        emit(NotificationLoaded(updatedList,
            unreadCount: currentState.unreadCount));

        // 3. Update Cache
        try {
          final jsonList = updatedList.map((e) => e.toJson()).toList();
          await HiveHelper.cacheNotifications(jsonList);
        } catch (_) {}

        // 4. API Call
        try {
          await repository.followBack(event.userId);
        } catch (e) {
          // If already following (400), Keep it TRUE.
          if (e is DioException && e.response?.statusCode == 400) {
            return;
          }

          // If genuine error, Revert
          await HiveHelper.unfollowUser(event.userId);

          final revertedList = currentState.notifications.map((n) {
            if (n.sender.id == event.userId) {
              final revertedSender = n.sender.copyWith(isFollowing: false);
              return n.copyWith(isFollowedBack: false, sender: revertedSender);
            }
            return n;
          }).toList();
          emit(NotificationLoaded(revertedList,
              unreadCount: currentState.unreadCount));
        }
      }
    });

    on<MarkReadEvent>((event, emit) async {
      if (state is NotificationLoaded) {
        final currentState = state as NotificationLoaded;
        final updatedList = currentState.notifications.map((n) {
          return n.id == event.id ? n.copyWith(isRead: true) : n;
        }).toList();
        final newCount =
            currentState.unreadCount > 0 ? currentState.unreadCount - 1 : 0;
        emit(NotificationLoaded(updatedList, unreadCount: newCount));
        await repository.markAsRead(event.id);
      }
    });
  }
}
