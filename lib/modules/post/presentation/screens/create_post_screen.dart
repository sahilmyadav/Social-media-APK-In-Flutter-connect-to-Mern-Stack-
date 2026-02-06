import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this to pubspec.yaml
import '../../../../core/utils/snackbar_utils.dart';
import '../bloc/upload_bloc.dart';

enum UploadType { post, reel, story }

class CreatePostScreen extends StatefulWidget {
  final List<File> mediaFiles;
  final Uint8List? thumbnailData;
  final UploadType type;

  const CreatePostScreen({
    super.key,
    required this.mediaFiles,
    this.thumbnailData,
    this.type = UploadType.post
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();

  // Tagging State
  final List<Map<String, dynamic>> _selectedTags = [];

  // Music State
  Map<String, dynamic>? _selectedSong;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingSongId; // To track which song is previewing

  @override
  void dispose() {
    _captionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleUpload() {
    final bloc = context.read<UploadBloc>();
    String caption = _captionController.text;
    List<String> tagIds = _selectedTags.map((e) => e['_id'].toString()).toList();

    // If a song is selected, we can append a note or handle mute logic
    // The API takes audioId.

    switch (widget.type) {
      case UploadType.post:
        bloc.add(SubmitPost(
          files: widget.mediaFiles,
          caption: caption,
          tags: tagIds,
          visibility: 'public',
        ));
        break;
      case UploadType.reel:
        bloc.add(SubmitReel(
          video: widget.mediaFiles.first,
          caption: caption,
          tags: tagIds,
          audioId: _selectedSong != null ? _selectedSong!['id'] : null,
        ));
        break;
      case UploadType.story:
        bloc.add(SubmitStory(
          file: widget.mediaFiles.first,
          caption: caption,
          duration: 10,
        ));
        break;
    }
  }

  // --- Bottom Sheet: Tag People ---
  void _showTaggingSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _TagPeopleSheet(
        isDark: isDark,
        initialTags: _selectedTags,
        onTagsChanged: (updatedTags) {
          setState(() {
            _selectedTags.clear();
            _selectedTags.addAll(updatedTags);
          });
        },
      ),
    );
  }

  // --- Bottom Sheet: Add Music ---
  void _showMusicSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _MusicPickerSheet(
        isDark: isDark,
        audioPlayer: _audioPlayer,
        onSongSelected: (song) {
          setState(() => _selectedSong = song);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    String title = widget.type == UploadType.post ? "New Post" :
    widget.type == UploadType.reel ? "New Reel" : "New Story";

    ImageProvider? imageProvider;
    if (widget.type == UploadType.reel && widget.thumbnailData != null) {
      imageProvider = MemoryImage(widget.thumbnailData!);
    } else if (widget.mediaFiles.isNotEmpty) {
      imageProvider = FileImage(widget.mediaFiles.first);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          BlocBuilder<UploadBloc, UploadState>(
            builder: (context, state) {
              if (state is Uploading) {
                return Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor)),
                ));
              }
              return TextButton(
                onPressed: _handleUpload,
                child: const Text("Share", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          )
        ],
      ),
      body: BlocListener<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadSuccess) {
            SnackbarUtils.showSuccess(context, "$title Shared successfully!");
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state is UploadFailure) {
            SnackbarUtils.showError(context, state.error);
          }
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Main Content: Caption & Media ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        image: imageProvider != null
                            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                            : null,
                      ),
                      child: imageProvider == null ? const Icon(Icons.video_camera_back, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        style: TextStyle(color: textColor, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Write a caption...",
                          hintStyle: TextStyle(color: subTextColor),
                          border: InputBorder.none,
                        ),
                        maxLines: 4,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),

              // --- 2. Action Tiles (Insta Style) ---

              // Tag People
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text("Tag People", style: TextStyle(fontSize: 16, color: textColor)),
                subtitle: _selectedTags.isNotEmpty
                    ? Text("${_selectedTags.length} people tagged", style: const TextStyle(color: Colors.blue))
                    : null,
                leading: Icon(Icons.person_outline, color: textColor),
                trailing: Icon(Icons.chevron_right, color: subTextColor),
                onTap: () => _showTaggingSheet(context, isDark),
              ),
              Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),

              // Add Music (Reels Only)
              if (widget.type == UploadType.reel) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(_selectedSong != null ? _selectedSong!['name'] : "Add Music",
                    style: TextStyle(fontSize: 16, color: _selectedSong != null ? Colors.blue : textColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _selectedSong != null
                      ? Text("Original audio will be muted", style: TextStyle(color: subTextColor, fontSize: 12))
                      : null,
                  leading: Icon(Icons.music_note_outlined, color: textColor),
                  trailing: _selectedSong != null
                      ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => setState(() => _selectedSong = null),
                  )
                      : Icon(Icons.chevron_right, color: subTextColor),
                  onTap: () => _showMusicSheet(context, isDark),
                ),
                Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
              ],

              // Removed Hardcoded Location/Advanced options as requested
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// ----------------------- SEARCH USERS SHEET (INTERNAL) ------------------------
// ==============================================================================

class _TagPeopleSheet extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> initialTags;
  final Function(List<Map<String, dynamic>>) onTagsChanged;

  const _TagPeopleSheet({
    required this.isDark,
    required this.initialTags,
    required this.onTagsChanged
  });

  @override
  State<_TagPeopleSheet> createState() => _TagPeopleSheetState();
}

class _TagPeopleSheetState extends State<_TagPeopleSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _currentTags = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentTags.addAll(widget.initialTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(BuildContext context, String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        context.read<UploadBloc>().add(SearchUsersEvent(query));
      } else {
        context.read<UploadBloc>().add(ClearSearchEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black;
    final subTextColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = widget.isDark ? Colors.grey[900] : Colors.white;
    final inputFill = widget.isDark ? Colors.grey[800] : Colors.grey[100];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text("Tag People", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),

          // Search Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => _onSearchChanged(context, q),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search users",
                hintStyle: TextStyle(color: subTextColor),
                prefixIcon: Icon(Icons.search, color: subTextColor),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              autofocus: true,
            ),
          ),

          // Selected Chips
          if (_currentTags.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _currentTags.map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(user['username'], style: TextStyle(color: textColor)),
                      backgroundColor: inputFill,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _currentTags.remove(user);
                          widget.onTagsChanged(_currentTags);
                        });
                      },
                      avatar: CircleAvatar(
                        backgroundImage: user['avatar'] != null ? NetworkImage("https://clikkme.in${user['avatar']}") : null,
                        child: user['avatar'] == null ? Text(user['firstName'][0]) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const Divider(),

          // List
          Expanded(
            child: BlocBuilder<UploadBloc, UploadState>(
              builder: (context, state) {
                if (state is UploadSearchState && state.users.isNotEmpty) {
                  return ListView.builder(
                    itemCount: state.users.length,
                    itemBuilder: (context, index) {
                      final user = state.users[index];
                      final isSelected = _currentTags.any((t) => t['_id'] == user['_id']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar'] != null ? NetworkImage("https://clikkme.in${user['avatar']}") : null,
                          child: user['avatar'] == null ? Text(user['firstName'][0]) : null,
                        ),
                        title: Text(user['username'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        subtitle: Text(user['fullName'] ?? "", style: TextStyle(color: subTextColor)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : Icon(Icons.circle_outlined, color: subTextColor),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _currentTags.removeWhere((t) => t['_id'] == user['_id']);
                            } else {
                              _currentTags.add(user);
                            }
                            widget.onTagsChanged(_currentTags);
                          });
                        },
                      );
                    },
                  );
                }
                return Center(child: Text("Search for people", style: TextStyle(color: subTextColor)));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// ----------------------- SEARCH MUSIC SHEET (INTERNAL) ------------------------
// ==============================================================================

class _MusicPickerSheet extends StatefulWidget {
  final bool isDark;
  final AudioPlayer audioPlayer;
  final Function(Map<String, dynamic>) onSongSelected;

  const _MusicPickerSheet({
    required this.isDark,
    required this.audioPlayer,
    required this.onSongSelected
  });

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String? _previewingUrl;

  @override
  void initState() {
    super.initState();
    // Trigger initial search for "Trending"
    context.read<UploadBloc>().add(SearchSongsEvent("trending hits"));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    widget.audioPlayer.stop(); // Stop music when sheet closes
    super.dispose();
  }

  void _onSearchChanged(BuildContext context, String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<UploadBloc>().add(SearchSongsEvent(query.isEmpty ? "trending hits" : query));
    });
  }

  Future<void> _togglePreview(String url) async {
    if (_previewingUrl == url) {
      // Stop
      await widget.audioPlayer.stop();
      setState(() => _previewingUrl = null);
    } else {
      // Play
      await widget.audioPlayer.stop();
      setState(() => _previewingUrl = url);
      await widget.audioPlayer.play(UrlSource(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black;
    final subTextColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];
    final inputFill = widget.isDark ? Colors.grey[800] : Colors.grey[100];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text("Music", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => _onSearchChanged(context, q),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search music",
                hintStyle: TextStyle(color: subTextColor),
                prefixIcon: Icon(Icons.search, color: subTextColor),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          Expanded(
            child: BlocBuilder<UploadBloc, UploadState>(
              builder: (context, state) {
                if (state is UploadSongSearchState) {
                  if (state.songs.isEmpty) {
                    return Center(child: Text("No songs found", style: TextStyle(color: subTextColor)));
                  }

                  return ListView.builder(
                    itemCount: state.songs.length,
                    itemBuilder: (context, index) {
                      final song = state.songs[index];
                      // Extract best download URL for preview (e.g., 96kbps or last in list)
                      final downloadUrls = song['downloadUrl'] as List<dynamic>?;
                      String? previewUrl;
                      if (downloadUrls != null && downloadUrls.isNotEmpty) {
                        // Try to find 96kbps, else take last
                        var match = downloadUrls.firstWhere((e) => e['quality'] == '96kbps', orElse: () => downloadUrls.last);
                        previewUrl = match['url'];
                      }

                      final imageUrl = (song['image'] as List?)?.last['url'];
                      final artists = (song['artists']?['primary'] as List?)?.map((e) => e['name']).join(', ') ?? "Unknown";
                      final isPlaying = _previewingUrl == previewUrl;

                      return ListTile(
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(imageUrl ?? "", width: 50, height: 50, fit: BoxFit.cover),
                            ),
                            if (previewUrl != null)
                              GestureDetector(
                                onTap: () => _togglePreview(previewUrl!),
                                child: Container(
                                  width: 50, height: 50,
                                  color: Colors.black.withOpacity(0.3),
                                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Text(song['name'], style: TextStyle(color: textColor, fontWeight: FontWeight.w600), maxLines: 1),
                        subtitle: Text(artists, style: TextStyle(color: subTextColor, fontSize: 12), maxLines: 1),
                        trailing: SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () => widget.onSongSelected(song),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlaying ? Colors.blue : Colors.grey[200],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Text("Use", style: TextStyle(color: isPlaying ? Colors.white : Colors.black)),
                          ),
                        ),
                      );
                    },
                  );
                }
                return Center(child: CircularProgressIndicator(color: textColor));
              },
            ),
          ),
        ],
      ),
    );
  }
}