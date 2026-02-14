import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../settings/presentation/screens/settings_screen.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/profile_skeleton.dart';
import '../../../../core/utils/snackbar_utils.dart';
import 'post_details_screen.dart';
import 'reel_player_screen.dart';
import 'reel_grid_item.dart'; // Ensure this matches your file name

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<ProfileBloc>().add(FetchProfile(widget.userId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- IMPROVED URL FIXER ---
  String _fixUrl(String? url) {
    if (url == null ||
        url.isEmpty ||
        url.toLowerCase() == "null" ||
        url.toLowerCase() == "undefined") {
      return "";
    }
    if (url.startsWith("http")) return url;
    return "https://clikkme.in$url";
  }

  Future<void> _onRefresh() async {
    context.read<ProfileBloc>().add(RefreshProfile(widget.userId));
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  // --- REPORT DIALOG ---
  void _showReportReasonDialog(BuildContext context, String userId) {
    final profileBloc = context.read<ProfileBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text("Report Account",
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportReasonItem(ctx, profileBloc, userId, "Spam"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Harassment"),
              _buildReportReasonItem(
                  ctx, profileBloc, userId, "Inappropriate Content"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Fake Account"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Other"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportReasonItem(
      BuildContext ctx, ProfileBloc bloc, String userId, String reason) {
    return ListTile(
      title: Text(reason,
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black)),
      onTap: () {
        Navigator.pop(ctx);
        bloc.add(ReportUserEvent(userId, reason));
        SnackbarUtils.showSuccess(context, "Report submitted: $reason");
      },
    );
  }

  // --- PROFESSIONAL BOTTOM SHEET ---
  void _showMoreOptions(BuildContext context, String userId, bool isBlocked) {
    final profileBloc = context.read<ProfileBloc>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: profileBloc,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5)
              ],
            ),
            padding: const EdgeInsets.only(bottom: 24, top: 10),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  if (!isBlocked) ...[
                    _buildOptionTile(
                        icon: HugeIcons.strokeRoundedShare01,
                        text: 'Share this profile',
                        textColor: textColor,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Share.share(
                              'Check out this profile on ClickME! https://clikkme.in/u/$userId');
                        }),
                    _buildOptionTile(
                        icon: HugeIcons.strokeRoundedLink01,
                        text: 'Copy profile URL',
                        textColor: textColor,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Clipboard.setData(ClipboardData(
                              text: 'https://clikkme.in/u/$userId'));
                          SnackbarUtils.showSuccess(
                              context, "Link copied to clipboard.");
                        }),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                  ],
                  _buildOptionTile(
                      icon: HugeIcons.strokeRoundedAlert01,
                      text: 'Report account',
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showReportReasonDialog(context, userId);
                      }),
                  _buildOptionTile(
                      icon: isBlocked
                          ? HugeIcons.strokeRoundedUserCheck01
                          : HugeIcons.strokeRoundedUserBlock01,
                      text: isBlocked ? 'Unblock user' : 'Block user',
                      textColor:
                          isBlocked ? Colors.blueAccent : Colors.redAccent,
                      iconColor:
                          isBlocked ? Colors.blueAccent : Colors.redAccent,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        if (isBlocked) {
                          profileBloc.add(UnblockUserEvent(userId));
                          SnackbarUtils.showSuccess(context, "User unblocked.");
                        } else {
                          profileBloc.add(BlockUserEvent(userId));
                          SnackbarUtils.showError(context, "User blocked.");
                          Navigator.pop(context);
                        }
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(
      {required dynamic icon,
      required String text,
      required Color textColor,
      Color? iconColor,
      required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? textColor).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: HugeIcon(icon: icon, color: iconColor ?? textColor, size: 22),
      ),
      title: Text(text,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: textColor, fontSize: 16)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const ProfileSkeleton();
          } else if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message,
                      style: TextStyle(color: textColor, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ProfileBloc>()
                        .add(FetchProfile(widget.userId)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF)),
                    child: const Text("Retry",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else if (state is ProfileLoaded) {
            final user = state.user;
            final isMe = state.isMe;
            final posts = state.posts;
            final reels = state.reels;
            final savedPosts = state.savedPosts;
            final savedReels = state.savedReels;

            // Update Tab Controller length if needed
            if (_tabController.length != (isMe ? 3 : 2)) {
              _tabController.dispose();
              _tabController = TabController(length: isMe ? 3 : 2, vsync: this);
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF6C63FF),
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // 1. Solid Background (White/Black)
                          Container(
                            height: 200,
                            width: double.infinity,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                          // Back Button
                          Positioned(
                            top: 40,
                            left: 16,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.05),
                                    shape: BoxShape.circle),
                                child: Icon(Icons.arrow_back,
                                    color: isDark ? Colors.white : Colors.black,
                                    size: 20),
                              ),
                            ),
                          ),
                          // Settings Button (if Me)
                          if (isMe)
                            Positioned(
                              top: 40,
                              right: 16,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SettingsScreen()));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.05),
                                      shape: BoxShape.circle),
                                  child: Icon(Icons.settings,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      size: 20),
                                ),
                              ),
                            ),

                          // 2. Profile Info & Stats Card
                          Column(
                            children: [
                              const SizedBox(height: 140), // Push down
                              // Avatar
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                        color: backgroundColor,
                                        shape: BoxShape.circle),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage:
                                          (user.profilePicture != null)
                                              ? CachedNetworkImageProvider(
                                                  _fixUrl(user.profilePicture))
                                              : null,
                                      child: user.profilePicture == null
                                          ? const Icon(Icons.person,
                                              size: 50, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF6C63FF),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt,
                                          color: Colors.white, size: 16),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text("${user.firstName} ${user.lastName}".trim(),
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      color: textColor)),
                              Text("@${user.username}",
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.grey)),

                              const SizedBox(height: 16),

                              // Buttons (Edit Profile or Follow/Message)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isMe) ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            // Navigate to Edit Profile
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6C63FF),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                          ),
                                          icon:
                                              const Icon(Icons.edit, size: 16),
                                          label: const Text("Edit Profile"),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            // Navigate to Edit Bio
                                          },
                                          style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: Colors.grey
                                                      .withOpacity(0.3)),
                                              foregroundColor: textColor),
                                          icon: const Icon(Icons.edit_note,
                                              size: 16),
                                          label: const Text("Edit Bio"),
                                        ),
                                      ),
                                    ] else if (user.isBlocked) ...[
                                      Expanded(
                                          child: ElevatedButton(
                                              onPressed: () => context
                                                  .read<ProfileBloc>()
                                                  .add(UnblockUserEvent(
                                                      user.id)),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent),
                                              child: const Text("Unblock")))
                                    ] else ...[
                                      Expanded(
                                          child: ElevatedButton(
                                              onPressed: () => context
                                                  .read<ProfileBloc>()
                                                  .add(ToggleFollowEvent(
                                                      user.id)),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      user.isFollowing
                                                          ? Colors.grey[800]
                                                          : const Color(
                                                              0xFF6C63FF)),
                                              child: Text(
                                                  user.isFollowing
                                                      ? "Unfollow"
                                                      : "Follow",
                                                  style: const TextStyle(
                                                      color: Colors.white)))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: OutlinedButton(
                                              onPressed: () {},
                                              child: Text("Message",
                                                  style: TextStyle(
                                                      color: textColor)))),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                          onPressed: () => _showMoreOptions(
                                              context, user.id, user.isBlocked),
                                          child: const Icon(Icons.more_horiz)),
                                    ]
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Stats Card
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: Colors.black.withOpacity(0.05),
                                  //     blurRadius: 10,
                                  //     offset: const Offset(0, 4),
                                  //   )
                                  // ]
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem("Posts", posts.length,
                                        textColor), // Use actual posts count
                                    const SizedBox(
                                        height: 30,
                                        child: VerticalDivider(
                                            color: Colors.grey,
                                            thickness: 0.5)),
                                    _buildStatItem("Followers",
                                        user.followersCount, textColor),
                                    const SizedBox(
                                        height: 30,
                                        child: VerticalDivider(
                                            color: Colors.grey,
                                            thickness: 0.5)),
                                    _buildStatItem("Following",
                                        user.followingCount, textColor),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                          TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF6C63FF),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: const Color(0xFF6C63FF),
                              indicatorWeight: 3,
                              tabs: [
                                const Tab(
                                    text: "Posts",
                                    icon: Icon(Icons.grid_on, size: 20)),
                                const Tab(
                                    text: "Reels",
                                    icon: Icon(Icons.video_library, size: 20)),
                                if (isMe)
                                  const Tab(
                                      text: "Saved",
                                      icon: Icon(Icons.bookmark_border,
                                          size: 20)),
                              ]),
                          backgroundColor),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // POSTS TAB
                    posts.isEmpty
                        ? _buildEmptyState("No posts yet",
                            HugeIcons.strokeRoundedCamera01, textColor)
                        : GridView.builder(
                            padding: const EdgeInsets.all(1),
                            physics:
                                const NeverScrollableScrollPhysics(), // NestedScrollView handles scroll
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 1,
                                    mainAxisSpacing: 1,
                                    childAspectRatio: 1),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              final mediaUrl = post.media.isNotEmpty
                                  ? post.media.first.fullUrl
                                  : "";
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PostDetailsScreen(postId: post.id),
                                    ),
                                  );
                                },
                                child: CachedNetworkImage(
                                    imageUrl: mediaUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey[900]),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error)),
                              );
                            },
                          ),

                    // REELS TAB
                    reels.isEmpty
                        ? _buildEmptyState("No reels yet",
                            HugeIcons.strokeRoundedVideo01, textColor)
                        : GridView.builder(
                            padding: const EdgeInsets.all(1),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 1,
                                    mainAxisSpacing: 1,
                                    childAspectRatio: 0.6),
                            itemCount: reels.length,
                            itemBuilder: (context, index) {
                              final reel = reels[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReelPlayerScreen(
                                        videoUrl: _fixUrl(reel.videoUrl),
                                        thumbnailUrl:
                                            _fixUrl(reel.thumbnailUrl),
                                      ),
                                    ),
                                  );
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ReelGridItem(
                                      thumbnailUrl: _fixUrl(reel.thumbnailUrl),
                                      videoUrl: _fixUrl(reel.videoUrl),
                                    ),
                                    const Positioned(
                                      bottom: 5,
                                      left: 5,
                                      child: Row(
                                        children: [
                                          Icon(Icons.play_arrow,
                                              color: Colors.white, size: 14),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),

                    // SAVED TAB (Only if isMe)
                    if (isMe)
                      savedPosts.isEmpty && savedReels.isEmpty
                          ? _buildEmptyState("No saved items",
                              Icons.bookmark_border, textColor)
                          : GridView.builder(
                              // Combined Grid or Separate? Let's just show Saved Posts for now as prompt implied mixed? Or just saved posts.
                              padding: const EdgeInsets.all(1),
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 1,
                                      mainAxisSpacing: 1,
                                      childAspectRatio: 1),
                              // Combining both for the grid for now, or just posts.
                              // User asked for "Saved" section. Usually saved posts.
                              itemCount: savedPosts.length + savedReels.length,
                              itemBuilder: (context, index) {
                                if (index < savedPosts.length) {
                                  final post = savedPosts[index];
                                  final mediaUrl = post.media.isNotEmpty
                                      ? post.media.first.fullUrl
                                      : "";
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => PostDetailsScreen(
                                                postId: post.id))),
                                    child: CachedNetworkImage(
                                        imageUrl: mediaUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            Container(color: Colors.grey[800]),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.error)),
                                  );
                                } else {
                                  final reel =
                                      savedReels[index - savedPosts.length];
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ReelPlayerScreen(
                                                videoUrl:
                                                    _fixUrl(reel.videoUrl),
                                                thumbnailUrl: _fixUrl(
                                                    reel.thumbnailUrl)))),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ReelGridItem(
                                            thumbnailUrl:
                                                _fixUrl(reel.thumbnailUrl),
                                            videoUrl: _fixUrl(reel.videoUrl)),
                                        const Positioned(
                                            bottom: 5,
                                            right: 5,
                                            child: Icon(Icons.video_library,
                                                color: Colors.white, size: 16))
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text("Something went wrong"));
        },
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(children: [
      Text("$count",
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 18, color: color)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13))
    ]);
  }

  Widget _buildEmptyState(String text, dynamic icon, Color color) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 400,
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon is IconData
              ? Icon(icon, size: 48, color: Colors.grey.withOpacity(0.5))
              : HugeIcon(
                  icon: icon, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: color, fontSize: 16))
        ]),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _backgroundColor;
  _SliverAppBarDelegate(this._tabBar, this._backgroundColor);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
