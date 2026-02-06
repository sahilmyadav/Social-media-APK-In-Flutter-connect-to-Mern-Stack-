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

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
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

  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    if (url.startsWith("http")) return url;
    return "https://clikkme.in$url";
  }

  Future<void> _onRefresh() async {
    context.read<ProfileBloc>().add(RefreshProfile(widget.userId));
    // Simulated delay to show the refresh spinner
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
          title: Text("Report Account", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportReasonItem(ctx, profileBloc, userId, "Spam"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Harassment"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Inappropriate Content"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Fake Account"),
              _buildReportReasonItem(ctx, profileBloc, userId, "Other"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportReasonItem(BuildContext ctx, ProfileBloc bloc, String userId, String reason) {
    return ListTile(
      title: Text(reason, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 5)
              ],
            ),
            padding: const EdgeInsets.only(bottom: 24, top: 10),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                  ),

                  if (!isBlocked) ...[
                    _buildOptionTile(
                        icon: HugeIcons.strokeRoundedShare01,
                        text: 'Share this profile',
                        textColor: textColor,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Share.share('Check out this profile on ClickME! https://clikkme.in/u/$userId');
                        }
                    ),
                    _buildOptionTile(
                        icon: HugeIcons.strokeRoundedLink01,
                        text: 'Copy profile URL',
                        textColor: textColor,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Clipboard.setData(ClipboardData(text: 'https://clikkme.in/u/$userId'));
                          SnackbarUtils.showSuccess(context, "Link copied to clipboard.");
                        }
                    ),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                  ],

                  // Report
                  _buildOptionTile(
                      icon: HugeIcons.strokeRoundedAlert01,
                      text: 'Report account',
                      textColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showReportReasonDialog(context, userId);
                      }
                  ),

                  // Block / Unblock
                  _buildOptionTile(
                      icon: isBlocked ? HugeIcons.strokeRoundedUserCheck01 : HugeIcons.strokeRoundedUserBlock01,
                      text: isBlocked ? 'Unblock user' : 'Block user',
                      textColor: isBlocked ? Colors.blueAccent : Colors.redAccent,
                      iconColor: isBlocked ? Colors.blueAccent : Colors.redAccent,
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
                      }
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required dynamic icon,
    required String text,
    required Color textColor,
    Color? iconColor,
    required VoidCallback onTap
  }) {
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
      title: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor, fontSize: 16)),
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
            return Center(child: Text(state.message, style: TextStyle(color: textColor)));
          } else if (state is ProfileLoaded) {
            final user = state.user;
            final posts = state.posts;

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFF6C63FF),
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: backgroundColor,
                      expandedHeight: 200,
                      pinned: true,
                      elevation: 0,
                      leading: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 0, left: 0, right: 0, bottom: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    image: (user.coverPhoto != null || user.profilePicture != null)
                                        ? DecorationImage(
                                        image: CachedNetworkImageProvider(_fixUrl(user.coverPhoto ?? user.profilePicture)),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
                                    ) : null
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (user.profilePicture != null) ? CachedNetworkImageProvider(_fixUrl(user.profilePicture)) : null,
                                  child: user.profilePicture == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Text("${user.firstName} ${user.lastName}".trim(), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, color: textColor)),
                          Text("@${user.username}", style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 20),

                          // ACTION BUTTONS
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (user.isBlocked)
                                  Expanded(child: SizedBox(height: 40, child: ElevatedButton(onPressed: () => context.read<ProfileBloc>().add(UnblockUserEvent(user.id)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("Unblock"))))
                                else ...[
                                  Expanded(child: SizedBox(height: 40, child: ElevatedButton(
                                    onPressed: () => context.read<ProfileBloc>().add(ToggleFollowEvent(user.id)),
                                    style: ElevatedButton.styleFrom(backgroundColor: user.isFollowing ? (isDark ? Colors.grey[900] : Colors.white) : const Color(0xFF6C63FF), side: user.isFollowing ? BorderSide(color: Colors.grey.shade300) : BorderSide.none),
                                    child: Text(user.isFollowing ? "Unfollow" : "Follow", style: TextStyle(color: user.isFollowing ? textColor : Colors.white)),
                                  ))),
                                  const SizedBox(width: 10),
                                  Expanded(child: SizedBox(height: 40, child: OutlinedButton(onPressed: (){}, style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300)), child: Text("Message", style: TextStyle(color: textColor))))),
                                  const SizedBox(width: 10),
                                  SizedBox(height: 40, width: 40, child: OutlinedButton(onPressed: () => _showMoreOptions(context, user.id, user.isBlocked), style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, side: BorderSide(color: Colors.grey.shade300)), child: const Icon(Icons.more_horiz))),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (!user.isBlocked) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildStatItem("Posts", user.postsCount, textColor), _buildStatItem("Followers", user.followersCount, textColor), _buildStatItem("Following", user.followingCount, textColor)]),
                          const SizedBox(height: 20),
                          if (user.bio != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Text(user.bio!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: textColor))),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    if (!user.isBlocked)
                      SliverPersistentHeader(
                        delegate: _SliverAppBarDelegate(TabBar(controller: _tabController, labelColor: const Color(0xFF6C63FF), unselectedLabelColor: Colors.grey, indicatorColor: const Color(0xFF6C63FF), tabs: [Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [HugeIcon(icon: HugeIcons.strokeRoundedGrid, size: 20, color: Colors.grey), const SizedBox(width: 6), const Text("Posts")])), Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [HugeIcon(icon: HugeIcons.strokeRoundedVideoReplay, size: 20, color: Colors.grey), const SizedBox(width: 6), const Text("Reels")]))]), backgroundColor),
                        pinned: true,
                      ),
                  ];
                },
                body: user.isBlocked
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HugeIcon(icon: HugeIcons.strokeRoundedUserBlock01, size: 64, color: Colors.grey), const SizedBox(height: 16), Text("You have blocked this user", style: TextStyle(color: textColor))]))
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    posts.isEmpty
                        ? _buildEmptyState("No posts yet", HugeIcons.strokeRoundedCamera01, textColor)
                        : GridView.builder(
                      padding: const EdgeInsets.all(1),
                      // --- FIXED: ENABLE SCROLLING FOR REFRESH INDICATOR ---
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1, childAspectRatio: 1),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final mediaUrl = post.media.isNotEmpty ? post.media.first.fullUrl : "";
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailsScreen(postId: post.id),
                              ),
                            );
                          },
                          child: CachedNetworkImage(imageUrl: mediaUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[900]), errorWidget: (context, url, error) => const Icon(Icons.error)),
                        );
                      },
                    ),
                    _buildEmptyState("No reels yet", HugeIcons.strokeRoundedVideo01, textColor),
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
    return Column(children: [Text("$count", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: color)), const SizedBox(height: 4), Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13))]);
  }

  Widget _buildEmptyState(String text, dynamic icon, Color color) {
    // Wrapped in SingleChildScrollView to allow refresh even on empty state
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 400,
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [HugeIcon(icon: icon, size: 48, color: Colors.grey.withOpacity(0.5)), const SizedBox(height: 12), Text(text, style: TextStyle(color: color, fontSize: 16))]),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _backgroundColor, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}