import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core
import 'core/network/api_client.dart';

// Auth Module
import 'modules/auth/data/auth_repository_impl.dart';
import 'modules/auth/domain/auth_repository.dart';
import 'modules/auth/presentation/bloc/auth_bloc.dart';

// User/Profile Module
import 'modules/user/data/repositories/profile_repository_impl.dart';
import 'modules/user/domain/repositories/profile_repository.dart';
import 'modules/user/presentation/bloc/profile_bloc.dart';
import 'modules/user/data/repositories/search_repository.dart';
import 'modules/user/presentation/bloc/search_bloc.dart';

// Feed Module
import 'modules/feed/data/repositories/feed_repository_impl.dart';
import 'modules/feed/presentation/bloc/feed_bloc.dart';

// Post/Upload Module
import 'modules/post/data/repositories/upload_repository.dart';
import 'modules/post/presentation/bloc/upload_bloc.dart';

// Reels Module
import 'modules/reels/data/repositories/reels_repository.dart';
import 'modules/reels/presentation/bloc/reels_bloc.dart';

// Chat Module (NEW)
import 'modules/chat/data/repositories/chat_repository.dart';
import 'modules/chat/presentation/bloc/chat_bloc.dart';

import 'modules/notifications/data/repositories/notification_repository.dart';
import 'modules/notifications/presentation/bloc/notification_bloc.dart';

import 'modules/call/presentation/bloc/call_bloc.dart'; // Add this

import 'modules/story/data/repositories/story_repository.dart';
import 'modules/story/presentation/bloc/story_bloc.dart';

import 'modules/live/data/repositories/live_repository.dart';
import 'modules/live/presentation/bloc/live_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- Core ---
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => ApiClient(sl(), sl()));

  // --- Auth ---
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerFactory(() => AuthBloc(authRepository: sl()));

  // --- User/Profile ---
  sl.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl()));
  sl.registerFactory(() => ProfileBloc(sl()));

  sl.registerLazySingleton(() => SearchRepository(sl()));
  sl.registerFactory(() => SearchBloc(sl()));

  // --- Feed ---
  sl.registerLazySingleton(() => FeedRepositoryImpl(sl()));
  sl.registerFactory(() => FeedBloc(sl()));

  // --- Post/Upload ---
  sl.registerLazySingleton(() => UploadRepository(sl()));
  sl.registerFactory(() => UploadBloc(sl()));

  // --- Reels ---
  sl.registerLazySingleton(() => ReelsRepository(sl()));
  sl.registerFactory(() => ReelsBloc(sl()));

  // --- Chat (Singleton Repository to keep Socket alive) ---
  sl.registerLazySingleton(() => ChatRepository(sl()));
  sl.registerLazySingleton(() => ChatBloc(sl()));

  // --- Notifications ---
  sl.registerLazySingleton(() => NotificationRepository(sl()));
  sl.registerFactory(() => NotificationBloc(sl()));

  sl.registerFactory(() => CallBloc(sl()));

  sl.registerLazySingleton(() => StoryRepository(sl()));
  sl.registerFactory(() => StoryBloc(sl()));

  // --- Live ---
  sl.registerLazySingleton(() => LiveRepository(sl()));
  sl.registerFactory(() => LiveBloc(sl()));
}
