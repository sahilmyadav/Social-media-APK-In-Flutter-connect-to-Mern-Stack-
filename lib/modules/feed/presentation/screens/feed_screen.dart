import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart'; // Ensure hugeicons package is added
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

// Bloc & Repository Imports
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../notifications/presentation/screens/notification_screen.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../story/presentation/bloc/story_bloc.dart';
import '../../../story/presentation/widgets/story_bubbles_list.dart';
import '../../../live/presentation/screens/live_feed_screen.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../../../../injection_container.dart';
import '../../../../core/utils/snackbar_utils.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    // Determine Theme Mode
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // STRICT COLORS: Pure Black for Dark Mode, White for Light Mode
    final Color backgroundColor = isDark ? Colors.black : Colors.white;
    final Color iconColor = isDark ? Colors.white : Colors.black;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<FeedBloc>()..add(LoadFeed())),
        BlocProvider(create: (_) => sl<StoryBloc>()..add(FetchStories())),
        BlocProvider(
          create: (_) => NotificationBloc(sl<NotificationRepository>())
            ..add(LoadNotifications()),
        ),
      ],
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor, // Pure Black/White
          surfaceTintColor: Colors.transparent, // Removes Material 3 tint
          scrolledUnderElevation: 0, // Prevents color change on scroll
          elevation: 0,
          title: Text(
            'ClickMe',
            style: GoogleFonts.fredoka(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: iconColor,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            // 0. LIVE STREAM ICON
            IconButton(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedVideo01,
                  color: iconColor,
                  size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveFeedScreen()),
                );
              },
            ),

            // 1. NOTIFICATION ICON (Heart Style)
            BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                int unreadCount = 0;
                if (state is NotificationLoaded) {
                  unreadCount = state.unreadCount;
                }
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite,
                          color: iconColor,
                          size: 28),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationScreen()),
                        ).then((_) {
                          if (context.mounted) {
                            context
                                .read<NotificationBloc>()
                                .add(LoadNotifications());
                          }
                        });
                      },
                    ),
                    // Red Dot Badge
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // 2. MESSENGER ICON
            IconButton(
              icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMessenger,
                  color: iconColor,
                  size: 28),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()));
              },
            ),
          ],
        ),
        body: BlocConsumer<FeedBloc, FeedState>(
          listener: (context, state) {
            if (state is FeedError) {
              SnackbarUtils.showError(context, state.message);
            } else if (state is FeedLoaded && state.currentUser != null) {
              // Fetch my stories once we know who I am
              context
                  .read<StoryBloc>()
                  .add(FetchMyStories(state.currentUser!.id));
            }
          },
          builder: (context, state) {
            return _buildBody(context, state, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedState state, bool isDark) {
    // 1. Loading State (Skeleton)
    if (state is FeedLoading || state is FeedInitial) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => _buildShiningSkeleton(isDark),
      );
    }

    // 2. Loaded State
    if (state is FeedLoaded ||
        (state is FeedError && state.currentPosts.isNotEmpty)) {
      final posts =
          state is FeedLoaded ? state.posts : (state as FeedError).currentPosts;
      final suggestions =
          state is FeedLoaded ? state.suggestions : <UserEntity>[];
      final currentUser = state is FeedLoaded ? state.currentUser : null;

      return RefreshIndicator(
        color: isDark ? Colors.white : Colors.black,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        onRefresh: () async {
          context.read<FeedBloc>().add(RefreshFeed());
          context.read<StoryBloc>().add(FetchStories());
          if (currentUser != null) {
            context.read<StoryBloc>().add(FetchMyStories(currentUser.id));
          }
          context.read<NotificationBloc>().add(LoadNotifications());
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: posts.length + 2,
          itemBuilder: (context, index) {
            // INDEX 0: Stories
            if (index == 0) {
              return Column(
                children: [
                  StoryBubblesList(currentUser: currentUser),
                  const SizedBox(height: 10),
                ],
              );
            }

            // INDEX 1: First Post
            if (index == 1) {
              if (posts.isEmpty) return _buildEmptyState(isDark);
              return PostCard(post: posts[0]);
            }

            // INDEX 2: Suggestions (Inserted after 2nd post usually, or here after 1st)
            if (index == 2 && suggestions.isNotEmpty) {
              return Column(
                children: [
                  if (posts.length > 1) PostCard(post: posts[1]),
                  _buildFollowSuggestions(context, suggestions, isDark),
                ],
              );
            }

            // Remaining Posts
            final postIndex = suggestions.isNotEmpty ? index - 1 : index - 1;

            if (postIndex >= posts.length) return const SizedBox();
            return PostCard(post: posts[postIndex]);
          },
        ),
      );
    }

    // 3. Error State
    if (state is FeedError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
                icon: HugeIcons.strokeRoundedWifi01,
                size: 50,
                color: Colors.grey),
            const SizedBox(height: 10),
            Text(state.message,
                style: GoogleFonts.inter(color: Colors.grey),
                textAlign: TextAlign.center),
            TextButton(
              onPressed: () => context.read<FeedBloc>().add(LoadFeed()),
              child: const Text("Retry"),
            )
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildEmptyState(bool isDark) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Text(
          "Welcome to ClickMe!\nFollow people to see posts.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildFollowSuggestions(
      BuildContext context, List<UserEntity> users, bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: 280,
      color: isDark ? Colors.black : Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Suggested for you",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textColor)),
                Text("See all",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.blue)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (ctx, index) {
                final user = users[index];
                final bool isFollowing = user.isFollowing ?? false;
                String dpUrl = user.profilePicture ?? "";

                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (dpUrl.isNotEmpty)
                                ? CachedNetworkImageProvider(dpUrl)
                                : null,
                            child: (dpUrl.isEmpty)
                                ? Icon(Icons.person,
                                    size: 44, color: Colors.grey[500])
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            Text(user.username,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(user.firstName ?? "Suggested",
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(
                          height: 34,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!isFollowing) {
                                context
                                    .read<FeedBloc>()
                                    .add(FollowUserFromSuggestions(user.id));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? Colors.grey[300]
                                    : Colors.blue,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero),
                            child: Text(isFollowing ? "Following" : "Follow",
                                style: GoogleFonts.inter(
                                    color: isFollowing
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShiningSkeleton(bool isDark) {
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
                Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                )
              ],
            ),
          ),
          Container(width: double.infinity, height: 400, color: Colors.white),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
