import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audioplayers/audioplayers.dart'; // Add audioplayers: ^5.2.1 to pubspec
import 'package:video_player/video_player.dart'; // Add video_player: ^2.8.6 to pubspec
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

  // Media Playback State
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Music State
  Map<String, dynamic>? _selectedSong;
  double _audioStartTime = 0.0; // In seconds

  @override
  void initState() {
    super.initState();
    // Set Audio Context to ensure it plays over other system sounds if needed
    _audioPlayer.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
      ),
    ));

    if (widget.type == UploadType.reel && widget.mediaFiles.isNotEmpty) {
      _initializeVideo();
    }
  }

  void _initializeVideo() async {
    _videoController = VideoPlayerController.file(widget.mediaFiles.first);
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.setVolume(1.0); // Default to original audio
    _videoController!.play();
    setState(() {});
  }

  void _syncAudioWithVideoLoop() {
    if (_videoController == null || _selectedSong == null) return;

    Duration lastPosition = Duration.zero;

    _videoController!.addListener(() {
      if (_videoController == null || !_videoController!.value.isInitialized) return;

      final currentPos = _videoController!.value.position;

      // Detect Loop: If current position is LESS than last position (and not just starting), video looped.
      if (currentPos < lastPosition && lastPosition > const Duration(seconds: 1)) {
        // Video looped, seek audio back to start time
        _audioPlayer.seek(Duration(seconds: _audioStartTime.toInt()));
      }
      lastPosition = currentPos;
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _handleUpload() {
    // FIX: Stop media immediately when user clicks Share
    _audioPlayer.stop();
    _videoController?.pause();

    final bloc = context.read<UploadBloc>();
    String caption = _captionController.text;
    List<String> tagIds = _selectedTags.map((e) => e['_id'].toString()).toList();

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
          audioStartTime: _selectedSong != null ? _audioStartTime : null,
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

  // --- Bottom Sheet: Select Music ---
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
          Navigator.pop(context); // Close picker
          // Open Adjust Sheet immediately (Insta style)
          // Small delay to ensure pop animation clears and player doesn't glitch
          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              _openAdjustAudioSheet(context, isDark, song);
            }
          });
        },
      ),
    );
  }

  // --- Bottom Sheet: Adjust/Trim Audio ---
  void _openAdjustAudioSheet(BuildContext context, bool isDark, Map<String, dynamic> song) {
    // Determine preview URL (Prefer 96kbps, fallback to last available)
    final downloadUrls = song['downloadUrl'] as List<dynamic>?;
    String? previewUrl;
    if (downloadUrls != null && downloadUrls.isNotEmpty) {
      // Logic: Try to find specific quality, otherwise grab the one that looks like an mp4/aac
      var match = downloadUrls.firstWhere(
              (e) => e['quality'] == '96kbps',
          orElse: () => downloadUrls.last
      );
      previewUrl = match['url'];
    }

    if (previewUrl == null) {
      SnackbarUtils.showError(context, "Cannot play this song");
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // Prevent accidental closing while scrubbing
      backgroundColor: Colors.black, // Always dark for focus
      builder: (context) => _AdjustAudioSheet(
        isDark: isDark,
        videoController: _videoController,
        audioPlayer: _audioPlayer,
        songUrl: previewUrl!,
        songDuration: Duration(seconds: song['duration'] ?? 180),
        songName: song['name'],
        artistName: (song['artists']?['primary'] as List?)?.first['name'] ?? "Unknown",
        albumArt: (song['image'] as List?)?.last['url'],
        onConfirm: (startTime) {
          setState(() {
            _selectedSong = song;
            _audioStartTime = startTime;
          });

          // Mute original video, play selected audio from start time
          _videoController?.play();
          _videoController?.setVolume(0.0);

          _audioPlayer.setSourceUrl(previewUrl!);
          _audioPlayer.seek(Duration(seconds: startTime.toInt()));
          _audioPlayer.resume();
          _syncAudioWithVideoLoop();
        },
        onCancel: () {
          // If canceled, revert to original audio if no song was previously selected
          if (_selectedSong == null) {
            _videoController?.setVolume(1.0);
            _audioPlayer.stop();
          } else {
            // If we had a song selected before, seek back to *that* song's time
            _audioPlayer.seek(Duration(seconds: _audioStartTime.toInt()));
            _audioPlayer.resume();
          }
          // Ensure video keeps playing in loop
          _videoController?.play();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    String title = widget.type == UploadType.post ? "New Post" :
    widget.type == UploadType.reel ? "New Reel" : "New Story";

    Widget previewWidget;
    if (widget.type == UploadType.reel && _videoController != null && _videoController!.value.isInitialized) {
      previewWidget = AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else if (widget.mediaFiles.isNotEmpty) {
      previewWidget = Image.file(widget.mediaFiles.first, fit: BoxFit.cover);
    } else {
      previewWidget = Container(color: Colors.grey);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            _audioPlayer.stop();
            Navigator.pop(context);
          },
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
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                              width: 100, height: 100,
                              child: previewWidget
                          ),
                        ),
                      ),
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

              // --- 2. Action Tiles ---

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
                      ? Text("Original audio muted • Start: ${_audioStartTime.toInt()}s", style: TextStyle(color: subTextColor, fontSize: 12))
                      : null,
                  leading: Icon(Icons.music_note_outlined, color: textColor),
                  trailing: _selectedSong != null
                      ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedSong = null;
                        _videoController?.setVolume(1.0); // Unmute video
                        _audioPlayer.stop();
                      });
                    },
                  )
                      : Icon(Icons.chevron_right, color: subTextColor),
                  onTap: () => _showMusicSheet(context, isDark),
                ),
                Divider(height: 1, indent: 56, color: isDark ? Colors.grey[800] : const Color(0xFFEEEEEE)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// ----------------------- AUDIO ADJUST SHEET (INSTA STYLE) ---------------------
// ==============================================================================

class _AdjustAudioSheet extends StatefulWidget {
  final bool isDark;
  final VideoPlayerController? videoController;
  final AudioPlayer audioPlayer;
  final String songUrl;
  final Duration songDuration;
  final String songName;
  final String artistName;
  final String? albumArt;
  final Function(double) onConfirm;
  final VoidCallback onCancel;

  const _AdjustAudioSheet({
    required this.isDark,
    required this.videoController,
    required this.audioPlayer,
    required this.songUrl,
    required this.songDuration,
    required this.songName,
    required this.artistName,
    this.albumArt,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_AdjustAudioSheet> createState() => _AdjustAudioSheetState();
}

class _AdjustAudioSheetState extends State<_AdjustAudioSheet> {
  double _currentStartSeconds = 0.0;
  Duration _lastVideoPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startPreview();
  }

  void _startPreview() async {
    // FIX: Force video to play explicitly when sheet opens to run parallel with music
    if (widget.videoController != null) {
      if (!widget.videoController!.value.isPlaying) {
        await widget.videoController!.play();
      }
      widget.videoController!.setVolume(0.0); // Mute video audio
    }

    // Ensure player is stopped before starting new source
    await widget.audioPlayer.stop();
    await widget.audioPlayer.play(UrlSource(widget.songUrl));

    // Add loop listener
    widget.videoController?.addListener(_videoLoopListener);
  }

  void _videoLoopListener() {
    if (widget.videoController == null) return;

    final currentPos = widget.videoController!.value.position;

    // Check for loop: if current position jumped BACKWARDS significantly
    if (currentPos < _lastVideoPos && _lastVideoPos > const Duration(seconds: 1)) {
      // Video looped, seek audio back to selected start
      widget.audioPlayer.seek(Duration(seconds: _currentStartSeconds.toInt()));
    }
    _lastVideoPos = currentPos;
  }

  void _onSliderChange(double value) {
    setState(() {
      _currentStartSeconds = value;
    });
    // Seek audio immediately to give feedback on position
    widget.audioPlayer.seek(Duration(seconds: value.toInt()));
  }

  @override
  void dispose() {
    widget.videoController?.removeListener(_videoLoopListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Almost full screen
      color: Colors.black, // Always dark for immersive feel
      child: Column(
        children: [
          // Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const Text("Music", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () {
                    widget.onConfirm(_currentStartSeconds);
                    Navigator.pop(context);
                  },
                  child: const Text("Done", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),

          // Video Preview Area
          Expanded(
            child: Center(
              child: widget.videoController != null && widget.videoController!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: widget.videoController!.value.aspectRatio,
                child: VideoPlayer(widget.videoController!),
              )
                  : Container(color: Colors.grey[900], child: const Center(child: CircularProgressIndicator(color: Colors.white))),
            ),
          ),

          // Song Info & Scrubber
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(widget.albumArt ?? "", width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey, width: 50, height: 50)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.songName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(widget.artistName, style: const TextStyle(color: Colors.grey, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Audio Scrubber (Visual representation)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fake waveform background
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: const Center(child: Text("||||||||||||||||||||||||||||||", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontSize: 20))),
                    ),
                    // Real Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 48,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 4),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: _currentStartSeconds,
                        min: 0,
                        max: widget.songDuration.inSeconds.toDouble(),
                        onChanged: _onSliderChange,
                      ),
                    ),
                    // Current Time Indicator Text
                    Positioned(
                      top: -20,
                      child: Text(
                        "Start at: ${_formatDuration(Duration(seconds: _currentStartSeconds.toInt()))}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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
          Text("Tag People", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),

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

  // FIX: Flag to prevent stopping audio when we select a song (to move to next screen)
  bool _stopAudioOnDispose = true;

  @override
  void initState() {
    super.initState();
    context.read<UploadBloc>().add(SearchSongsEvent("trending hits"));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    if (_stopAudioOnDispose) {
      widget.audioPlayer.stop(); // Only stop if we are NOT moving to adjustment screen
    }
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
      await widget.audioPlayer.stop();
      setState(() => _previewingUrl = null);
    } else {
      await widget.audioPlayer.stop();
      setState(() => _previewingUrl = url);
      await widget.audioPlayer.play(UrlSource(url));
    }
  }

  void _handleSelection(Map<String, dynamic> song) {
    _stopAudioOnDispose = false; // Important: Don't kill audio, we need it in next screen
    widget.onSongSelected(song);
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
                      final downloadUrls = song['downloadUrl'] as List<dynamic>?;
                      String? previewUrl;
                      if (downloadUrls != null && downloadUrls.isNotEmpty) {
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
                            onPressed: () => _handleSelection(song),
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