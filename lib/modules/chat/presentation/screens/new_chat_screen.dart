import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injection_container.dart';
import '../../../user/data/repositories/search_repository.dart';
import '../../../user/presentation/bloc/search_bloc.dart';
import '../../../user/domain/entities/user_entity.dart';
import '../../data/repositories/chat_repository.dart';
import '../bloc/chat_bloc.dart';
import 'chat_detail_screen.dart';

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SearchBloc(SearchRepository(sl<ApiClient>()))..add(LoadExplore()),
      child: const NewChatView(),
    );
  }
}

class NewChatView extends StatefulWidget {
  const NewChatView({super.key});

  @override
  State<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends State<NewChatView> {
  final _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

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

  Future<void> _createThreadAndNavigate(UserEntity user) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final chatRepo = sl<ChatRepository>();
      final threadId = await chatRepo.createThread(user.id);

      if (mounted) Navigator.pop(context); // Dismiss loading

      if (mounted) {
        // Use the global ChatBloc
        final chatBloc = context.read<ChatBloc>();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              threadId: threadId,
              user: user,
              chatBloc: chatBloc,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start chat: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchFillColor =
        isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("New Message",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: Responsive.sp(18),
                color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: Responsive.padSymmetric(horizontal: 16),
            child: Container(
              height: Responsive.h(44),
              decoration: BoxDecoration(
                color: searchFillColor,
                borderRadius: BorderRadius.circular(Responsive.r(12)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: TextStyle(color: textColor, fontSize: Responsive.sp(16)),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(
                      color: Colors.grey[500], fontSize: Responsive.sp(16)),
                  prefixIcon: Padding(
                    padding: Responsive.padAll(10),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: Colors.grey[500]!,
                        size: Responsive.sp(20)),
                  ),
                  border: InputBorder.none,
                  contentPadding: Responsive.padSymmetric(vertical: 10),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: Icon(Icons.cancel,
                              color: Colors.grey, size: Responsive.sp(20)),
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
          SizedBox(height: Responsive.h(10)),

          // Content Area
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state is SearchInitial ||
                    (state is ExploreLoaded && !_isSearching)) {
                  return _buildSuggestedLabel();
                }
                if (state is SearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is SearchResultsLoaded) {
                  if (state.users.isEmpty) {
                    return Center(
                        child: Text("No users found",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: Responsive.sp(14))));
                  }
                  return _buildUserList(state.users, textColor, isDark);
                }
                if (state is SearchError) {
                  return Center(
                      child: Text(state.message,
                          style: TextStyle(
                              color: Colors.red, fontSize: Responsive.sp(14))));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedLabel() {
    return Center(
      child: Text("Search for people to chat with",
          style: TextStyle(color: Colors.grey, fontSize: Responsive.sp(14))),
    );
  }

  Widget _buildUserList(List<UserEntity> users, Color textColor, bool isDark) {
    return ListView.builder(
      padding: Responsive.padSymmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final avatarUrl = user.profilePicture;

        return ListTile(
          contentPadding: Responsive.padSymmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: Responsive.r(26),
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? CachedNetworkImageProvider("https://clikkme.in$avatarUrl")
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Icon(Icons.person,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: Responsive.sp(24))
                : null,
          ),
          title: Text(
            user.username,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(16),
                color: textColor),
          ),
          subtitle: Text(
            user.firstName,
            style: GoogleFonts.inter(
                color: Colors.grey, fontSize: Responsive.sp(14)),
          ),
          onTap: () => _createThreadAndNavigate(user),
        );
      },
    );
  }
}
