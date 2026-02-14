import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import '../bloc/story_bloc.dart';

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter(
      {this.color = Colors.grey, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(20)));

    Path dashPath = Path();
    double dashWidth = 10.0;
    double distance = 0.0;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _mediaFile;
  String _mediaType = 'image';
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      final XFile? pickedFile = isVideo
          ? await _picker.pickVideo(
              source: source, maxDuration: const Duration(seconds: 60))
          : await _picker.pickImage(source: source);

      if (pickedFile != null) {
        debugPrint("Media Picked: ${pickedFile.path}");

        if (isVideo) {
          try {
            _videoController?.dispose();
            _videoController =
                VideoPlayerController.file(File(pickedFile.path));
            await _videoController!.initialize();
            if (mounted) {
              setState(() {});
              _videoController?.play();
              _videoController?.setLooping(true);
            }
          } catch (e) {
            debugPrint("Video init error: $e");
            // Handle video error (maybe show snackbar or reset)
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to load video")));
              return;
            }
          }
        }

        if (mounted) {
          setState(() {
            _mediaFile = File(pickedFile.path);
            _mediaType = isVideo ? 'video' : 'image';
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  void _uploadStory() {
    if (_mediaFile == null) return;

    setState(() => _isUploading = true);

    int duration = 5;
    if (_mediaType == 'video' &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      duration = _videoController!.value.duration.inSeconds;
    }

    context.read<StoryBloc>().add(UploadStoryEvent(
          _mediaFile!,
          caption: _captionController.text.trim(),
          type: _mediaType,
          duration: duration,
        ));
  }

  void _clearSelection() {
    if (mounted) {
      setState(() {
        _mediaFile = null;
        _mediaType = 'image';
        _videoController?.dispose();
        _videoController = null;
        _captionController.clear();
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add to Story",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_mediaFile != null)
            TextButton(
              onPressed: _clearSelection,
              child: const Text("Retake", style: TextStyle(color: Colors.red)),
            )
        ],
      ),
      body: BlocListener<StoryBloc, StoryState>(
        listener: (context, state) {
          if (state is StoryUploadSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Story uploaded successfully")),
            );
            Navigator.pop(context);
          } else if (state is StoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            if (mounted) {
              setState(() => _isUploading = false);
            }
          }
        },
        child: _mediaFile == null
            ? _buildUploadPlaceholder()
            : _buildPreviewAndCaption(),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: CustomPaint(
            painter: DashedBorderPainter(
                color: Colors.grey.shade300, strokeWidth: 2, gap: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_outlined,
                      size: 40, color: Colors.deepPurple),
                ),
                const SizedBox(height: 20),
                const Text("Upload a Photo or Video",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 10),
                const Text("Share a moment with your followers",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    const Text("Images", style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 20),
                    const Icon(Icons.videocam_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    const Text("Videos", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => _showMediaPickerSheet(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E5BF0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Select File",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery (Image)'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Gallery (Video)'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewAndCaption() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Media Preview
          Container(
            height: 450, // Slightly taller
            width: double.infinity,
            color: Colors.black,
            alignment: Alignment.center,
            child: _mediaType == 'video'
                ? _videoController != null &&
                        _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!))
                    : const Center(child: CircularProgressIndicator())
                : Image.file(
                    _mediaFile!,
                    fit: BoxFit.contain, // Maintain aspect ratio
                    errorBuilder: (context, error, stack) => Center(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image,
                            color: Colors.white, size: 50),
                        Text("Could not load image\n$error",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    )),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: "Caption",
                hintText: "Write a caption...",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadStory,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isUploading ? "Uploading..." : "Share Story"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E5BF0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30))),
              ),
            ),
          )
        ],
      ),
    );
  }
}
