import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../injection_container.dart';
import '../../data/repositories/search_repository.dart';
import '../bloc/search_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../../../feed/domain/entities/post_entity.dart';

// Import Screens for Navigation
import '../../../user/presentation/screens/profile_screen.dart';
import '../../../user/presentation/screens/post_details_screen.dart';
import '../../../user/presentation/bloc/profile_bloc.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(SearchRepository(sl<ApiClient>()))..add(LoadExplore()),
      child: const SearchView(),
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<SearchBloc>().add(SearchQueryChanged(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchFillColor = isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- INSTA-STYLE SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: searchFillColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: TextStyle(color: textColor, fontSize: 16),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: "Search",
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: HugeIcon(
                                icon: HugeIcons.strokeRoundedSearch01,
                                color: Colors.grey[500]!,
                                size: 20
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: _isSearching
                              ? IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged("");
                            },
                          )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: _focusNode.hasFocus || _isSearching ? null : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _focusNode.unfocus();
                            _onSearchChanged("");
                          },
                          child: Text(
                            "Cancel",
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.inter(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENT AREA ---
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) {
                  // 1. LOADING (SKELETON)
                  if (state is SearchInitial || state is SearchLoading) {
                    return _buildSkeleton(isDark, isGrid: state is SearchInitial);
                  }

                  // 2. EXPLORE GRID (POSTS)
                  if (state is ExploreLoaded) {
                    if (state.posts.isEmpty) {
                      return _buildEmptyView(isDark, "No posts to explore", HugeIcons.strokeRoundedCamera01);
                    }
                    return _buildExploreGrid(state.posts);
                  }

                  // 3. SEARCH RESULTS (USERS)
                  if (state is SearchResultsLoaded) {
                    if (state.users.isEmpty) {
                      return _buildEmptyView(isDark, "No users found", HugeIcons.strokeRoundedUserBlock01);
                    }
                    return _buildUserList(state.users, textColor, isDark);
                  }

                  // 4. ERROR
                  if (state is SearchError) {
                    return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // 1. Grid with Video Support
  Widget _buildExploreGrid(List<PostEntity> posts) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
        childAspectRatio: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final media = post.media.isNotEmpty ? post.media.first : null;
        final isVideo = media?.type == 'video';

        // Use fullUrl if image, but for video we use placeholder to avoid 'Break Icon'
        final mediaUrl = media?.fullUrl ?? "";

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: post.id)),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // BACKGROUND CONTENT
              if (isVideo)
                Container(
                  color: Colors.grey[900], // Dark background for video
                  child: const Center(
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 40),
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  memCacheHeight: 300, // Memory optimization
                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),

              // VIDEO ICON OVERLAY (Top Right)
              if (isVideo)
                Positioned(
                  top: 6,
                  right: 6,
                  // FIX: Changed Icon -> HugeIcon because HugeIcons.xxx is vector data
                  child: HugeIcon(
                      icon: HugeIcons.strokeRoundedVideoReplay,
                      color: Colors.white,
                      size: 18
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 2. User List
  Widget _buildUserList(List<UserEntity> users, Color textColor, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        String avatarUrl = user.profilePicture ?? "";
        if (avatarUrl.startsWith("/")) avatarUrl = "https://clikkme.in$avatarUrl";

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            backgroundImage: (avatarUrl.isNotEmpty && avatarUrl.startsWith("http"))
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: (avatarUrl.isEmpty || !avatarUrl.startsWith("http"))
                ? Icon(Icons.person, color: isDark ? Colors.grey[500] : Colors.grey[400])
                : null,
          ),
          title: Text(
            user.username,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: textColor),
          ),
          subtitle: Text(
            user.firstName,
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
          trailing: _isSearching ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey) : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                    create: (_) => sl<ProfileBloc>(),
                    child: ProfileScreen(userId: user.id)
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyView(bool isDark, String text, dynamic icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(text, style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  // 3. Skeleton
  Widget _buildSkeleton(bool isDark, {required bool isGrid}) {
    final baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: isGrid
          ? GridView.builder(
        padding: EdgeInsets.zero,
        itemCount: 18,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 1.5, mainAxisSpacing: 1.5),
        itemBuilder: (_, __) => Container(color: Colors.white),
      )
          : ListView.builder(
        itemCount: 10,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const CircleAvatar(radius: 26, backgroundColor: Colors.white),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}