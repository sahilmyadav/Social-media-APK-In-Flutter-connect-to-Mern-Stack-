import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../injection_container.dart';
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
    // Auto-focus the search bar when opening "New Chat"
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
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final chatRepo = sl<ChatRepository>();
      final threadId = await chatRepo.createThread(user.id);

      // Dismiss loading
      if (mounted) Navigator.pop(context);

      // Navigate to ChatDetail
      if (mounted) {
        // Need to pass the ChatBloc from the previous screen (ChatListScreen context)
        // BUT we are in a new route. We should probably use DI or pass it if possible.
        // For now, let's create a fresh ChatBloc or use the one from DI since ChatListScreen provided it locally.
        // Actually, ChatListScreen created a BlocProvider. We can't access it here easily unless passed.
        // BETTER: Use Dependency Injection for ChatBloc in ChatDetailScreen if it's not passed,
        // OR rely on the fact that ChatDetailScreen typically expects one.

        // Simpler: Just resolve a fresh block or use global if available.
        // Given existing code structure, ChatDetailScreen takes a `chatBloc`.
        // We will resolve a new one from SL since we are starting a fresh chat session.

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              threadId: threadId,
              user: user,
              chatBloc: sl<ChatBloc>()
                ..add(InitChat()), // Initialize fresh bloc
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start chat: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final searchFillColor =
        isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("New Message",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
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
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: Colors.grey[500]!,
                        size: 20),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.cancel,
                              color: Colors.grey, size: 20),
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
          const SizedBox(height: 10),

          // --- CONTENT AREA ---
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                // 1. SUGGESTED / INITIAL
                if (state is SearchInitial ||
                    (state is ExploreLoaded && !_isSearching)) {
                  return _buildSuggestedLabel();
                }

                // 2. LOADING
                if (state is SearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 3. SEARCH RESULTS (USERS)
                if (state is SearchResultsLoaded) {
                  if (state.users.isEmpty) {
                    return Center(
                        child: Text("No users found",
                            style: TextStyle(color: Colors.grey)));
                  }
                  return _buildUserList(state.users, textColor, isDark);
                }

                // 4. ERROR
                if (state is SearchError) {
                  return Center(
                      child: Text(state.message,
                          style: const TextStyle(color: Colors.red)));
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
          style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildUserList(List<UserEntity> users, Color textColor, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final avatarUrl = user.profilePicture;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            backgroundImage:
                (avatarUrl != null && avatarUrl.isNotEmpty) // Simplified helper
                    ? CachedNetworkImageProvider("https://clikkme.in$avatarUrl")
                    : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Icon(Icons.person,
                    color: isDark ? Colors.grey[500] : Colors.grey[400])
                : null,
          ),
          title: Text(
            user.username,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 16, color: textColor),
          ),
          subtitle: Text(
            user.firstName,
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
          ),
          onTap: () => _createThreadAndNavigate(user),
        );
      },
    );
  }
}
