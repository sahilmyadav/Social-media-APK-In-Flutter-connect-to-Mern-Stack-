import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/bloc/feed_bloc.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/data/repositories/feed_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/entities/user_entity.dart';

class SinglePostFeedRepository extends FeedRepositoryImpl {
  PostEntity? _targetPost;

  SinglePostFeedRepository(ApiClient apiClient) : super(apiClient);

  void setTargetPost(PostEntity post) {
    _targetPost = post;
  }

  @override
  Future<List<PostEntity>> getRemoteFeed({int page = 1}) async {
    if (_targetPost != null) return [_targetPost!];
    return [];
  }

  @override
  Future<List<UserEntity>> getFollowSuggestions() async => [];

  @override
  Future<UserEntity?> getCurrentUser() async => null;
}

class PostDetailsScreen extends StatefulWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  late Future<PostEntity> _initialFetch;
  final ProfileRepository _profileRepository = sl<ProfileRepository>();
  final ApiClient _apiClient = sl<ApiClient>();

  late FeedBloc _localFeedBloc;
  late SinglePostFeedRepository _customRepo;

  @override
  void initState() {
    super.initState();
    _customRepo = SinglePostFeedRepository(_apiClient);
    _localFeedBloc = FeedBloc(_customRepo);
    _initialFetch = _loadPostAndInitBloc();
  }

  Future<PostEntity> _loadPostAndInitBloc() async {
    try {
      PostEntity post = await _profileRepository.getPostDetails(widget.postId);

      final results = await Future.wait([
        _apiClient.dio.get('/post/user-saved-posts', queryParameters: {'limit': 100}),
        _apiClient.dio.get('/users/current-user'),
      ]);

      final savedRes = results[0] as Response;
      if (savedRes.data['data'] != null) {
        final rawData = savedRes.data['data'];
        final List savedList = rawData is List ? rawData : (rawData['posts'] ?? []);
        final isSaved = savedList.any((e) => e['_id'] == post.id);
        post = post.copyWith(isSaved: isSaved);
      }

      final userRes = results[1] as Response;
      if (userRes.data['data'] != null) {
        final myId = userRes.data['data']['_id'];

        if (myId != null) {
          final followRes = await _apiClient.dio.get('/follow/following/$myId', queryParameters: {'limit': 100});
          if (followRes.data['data'] != null) {
            final List followingList = followRes.data['data']['following'] ?? [];
            final isFollowing = followingList.any((e) => e['_id'] == post.user.id);
            post = post.copyWith(user: post.user.copyWith(isFollowing: isFollowing));
          }
        }
      }

      if (Hive.isBoxOpen('feed_box')) {
        final box = Hive.box('feed_box');
        final rawFeed = box.get('home_feed', defaultValue: []);

        if (rawFeed is List) {
          Map<dynamic, dynamic>? cachedPostMap;
          for (var item in rawFeed) {
            final itemId = item['_id'] ?? item['id'];
            if (itemId.toString() == post.id) {
              cachedPostMap = item as Map<dynamic, dynamic>;
              break;
            }
          }

          if (cachedPostMap != null) {
            final isLiked = cachedPostMap['isLiked'] == true;
            final likesCount = int.tryParse(cachedPostMap['likes_count'].toString()) ?? post.likesCount;

            post = post.copyWith(isLiked: isLiked, likesCount: likesCount);
          }
        }
      }

      _customRepo.setTargetPost(post);
      _localFeedBloc.add(LoadFeed());

      return post;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _localFeedBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Post", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: textColor)),
        centerTitle: true,
      ),
      body: BlocProvider.value(
        value: _localFeedBloc,
        child: FutureBuilder<PostEntity>(
          future: _initialFetch,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // FIX: Wrapped Skeleton in SingleChildScrollView to prevent overflow
              return SingleChildScrollView(child: _buildSkeleton(isDark));
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text("Post unavailable", style: GoogleFonts.inter(color: Colors.grey)),
                    TextButton(
                        onPressed: () => setState(() => _initialFetch = _loadPostAndInitBloc()),
                        child: const Text("Retry")
                    )
                  ],
                ),
              );
            }

            return BlocBuilder<FeedBloc, FeedState>(
              builder: (context, state) {
                PostEntity displayPost;
                if (state is FeedLoaded && state.posts.isNotEmpty) {
                  displayPost = state.posts.first;
                } else {
                  displayPost = snapshot.data!;
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      PostCard(post: displayPost),
                      const SizedBox(height: 50),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  ],
                )
              ],
            ),
          ),
          Container(width: double.infinity, height: 400, color: Colors.white),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 15),
                Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 15),
                Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ],
            ),
          )
        ],
      ),
    );
  }
}