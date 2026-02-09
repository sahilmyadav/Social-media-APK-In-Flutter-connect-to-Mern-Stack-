import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ReelGridItem extends StatefulWidget {
  final String? thumbnailUrl;
  final String videoUrl;

  const ReelGridItem({
    super.key,
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  @override
  State<ReelGridItem> createState() => _ReelGridItemState();
}

class _ReelGridItemState extends State<ReelGridItem> with AutomaticKeepAliveClientMixin {
  Uint8List? _thumbnailBytes;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeThumbnail();
  }

  void _initializeThumbnail() {
    final thumb = widget.thumbnailUrl;
    // 1. If valid image URL exists, do nothing (build method handles it)
    if (thumb != null && thumb.isNotEmpty && _isImage(thumb)) {
      return;
    }
    // 2. Otherwise, generate from Video
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (widget.videoUrl.isEmpty) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint("🎬 Generating thumbnail for: ${widget.videoUrl}");

      // Generate in memory (Uint8List) to avoid file permission issues
      final Uint8List? bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200, // Keep small for grid performance
        quality: 50,
      );

      if (mounted) {
        if (bytes != null) {
          debugPrint("✅ Thumbnail generated successfully!");
          setState(() {
            _thumbnailBytes = bytes;
            _isLoading = false;
          });
        } else {
          debugPrint("⚠️ Thumbnail generated but returned null");
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error generating thumbnail: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  bool _isImage(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // CASE A: Remote Image (Valid URL)
    if (widget.thumbnailUrl != null &&
        widget.thumbnailUrl!.isNotEmpty &&
        _isImage(widget.thumbnailUrl!)) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => _buildErrorFallback(),
      );
    }

    // CASE B: Generated Memory Image
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorFallback(),
      );
    }

    // CASE C: Loading
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)
            )
        ),
      );
    }

    // CASE D: Fallback (Video Icon)
    return _buildErrorFallback();
  }

  Widget _buildErrorFallback() {
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 32),
      ),
    );
  }
}