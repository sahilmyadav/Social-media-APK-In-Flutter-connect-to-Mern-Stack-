import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'create_post_screen.dart'; // Next screen for caption
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  List<AssetEntity> _assets = [];
  AssetEntity? _selectedAsset;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    // Request permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      // Fetch recent albums
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
      List<AssetEntity> media = await albums[0].getAssetListRange(start: 0, end: 100);

      setState(() {
        _assets = media;
        _selectedAsset = media.first;
      });
      _loadFile(_selectedAsset!);
    }
  }

  Future<void> _loadFile(AssetEntity asset) async {
    File? file = await asset.file;
    setState(() {
      _selectedFile = file;
      _selectedAsset = asset;
    });
  }

  void _onNext() {
    if (_selectedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePostScreen(imageFile: _selectedFile!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("New Post", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _onNext,
            child: const Text("Next", style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Top Preview Area (Insta Style)
          Container(
            height: 375, // Approx square + extra
            width: double.infinity,
            color: Colors.black,
            child: _selectedFile != null
                ? Image.file(_selectedFile!, fit: BoxFit.contain)
                : const Center(child: CircularProgressIndicator()),
          ),

          // 2. Toolbar (Recents, Camera Button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recents", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  onPressed: () {
                    // Open Camera
                  },
                ),
              ],
            ),
          ),

          // 3. Bottom Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, index) {
                final asset = _assets[index];
                return GestureDetector(
                  onTap: () => _loadFile(asset),
                  child: Opacity(
                    opacity: _selectedAsset == asset ? 0.5 : 1.0,
                    child: AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(200),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}