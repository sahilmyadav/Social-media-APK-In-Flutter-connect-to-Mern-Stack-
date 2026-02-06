import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'create_post_screen.dart';

class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _assets = [];
  List<AssetEntity> _selectedAssets = [];
  bool _isMultipleMode = false;

  int _currentPage = 0;
  bool _hasMore = true;
  final int _pageSize = 80;

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.all,
        hasAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (albums.isNotEmpty) {
        setState(() {
          _albums = albums;
          _selectedAlbum = albums.first;
        });
        _fetchAssets(albums.first, reset: true);
      }
    } else {
      PhotoManager.openSetting();
    }
  }

  Future<void> _fetchAssets(AssetPathEntity album, {bool reset = false}) async {
    if (reset) {
      _assets = [];
      _currentPage = 0;
      _hasMore = true;
    }

    if (!_hasMore) return;

    final assets = await album.getAssetListPaged(page: _currentPage, size: _pageSize);

    setState(() {
      _assets.addAll(assets);
      _currentPage++;
      if (assets.length < _pageSize) _hasMore = false;
      if (_assets.isNotEmpty && _selectedAssets.isEmpty) {
        _selectedAssets = [_assets.first];
      }
    });
  }

  Future<File?> _cropImage(File file) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Edit Photo',
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  void _onNext() async {
    if (_selectedAssets.isEmpty) return;

    List<File> processedFiles = [];
    Uint8List? thumbnailData;

    UploadType type = _selectedAssets.first.type == AssetType.video
        ? UploadType.reel
        : UploadType.post;

    // Get thumbnail for the first asset (useful if it's a video)
    thumbnailData = await _selectedAssets.first.thumbnailData;

    for (var asset in _selectedAssets) {
      final file = await asset.file;
      if (file != null) {
        if (asset.type == AssetType.image) {
          File? cropped = await _cropImage(file);
          processedFiles.add(cropped ?? file);
        } else {
          processedFiles.add(file);
        }
      }
    }

    if (processedFiles.isEmpty) return;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          mediaFiles: processedFiles,
          thumbnailData: thumbnailData, // PASS THUMBNAIL HERE
          type: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Dark Mode Setup ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;
    final previewBackgroundColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final dropdownColor = isDark ? Colors.grey[900] : Colors.white;
    final multiSelectInactiveColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<AssetPathEntity>(
            value: _selectedAlbum,
            icon: Icon(Icons.keyboard_arrow_down, color: iconColor),
            dropdownColor: dropdownColor,
            items: _albums.map((album) => DropdownMenuItem(
              value: album,
              child: Text(
                album.name.length > 20 ? "${album.name.substring(0, 20)}..." : album.name,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: (AssetPathEntity? album) {
              if (album != null && album != _selectedAlbum) {
                setState(() {
                  _selectedAlbum = album;
                  _selectedAssets.clear();
                });
                _fetchAssets(album, reset: true);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: _onNext,
            child: const Text("Next", style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: previewBackgroundColor,
              child: _selectedAssets.isNotEmpty
                  ? AssetEntityImage(
                _selectedAssets.last,
                isOriginal: false,
                fit: BoxFit.contain,
              )
                  : Center(child: CircularProgressIndicator(color: textColor)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: backgroundColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recents", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMultipleMode = !_isMultipleMode;
                      if (!_isMultipleMode && _selectedAssets.length > 1) {
                        _selectedAssets = [_selectedAssets.last];
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isMultipleMode ? Colors.blue : multiSelectInactiveColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.layers, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scroll) {
                if (!_hasMore) return false;
                if (scroll.metrics.pixels == scroll.metrics.maxScrollExtent) {
                  if (_selectedAlbum != null) {
                    _fetchAssets(_selectedAlbum!);
                  }
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final isSelected = _selectedAssets.contains(asset);
                  final selectionIndex = _selectedAssets.indexOf(asset) + 1;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_isMultipleMode) {
                          if (isSelected) {
                            _selectedAssets.remove(asset);
                          } else {
                            if (_selectedAssets.length < 10) {
                              _selectedAssets.add(asset);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Limit 10 photos"))
                              );
                            }
                          }
                        } else {
                          _selectedAssets = [asset];
                        }
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AssetEntityImage(
                            asset,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(250),
                            fit: BoxFit.cover,
                            opacity: AlwaysStoppedAnimation(isSelected ? 0.5 : 1.0),
                          ),
                        ),
                        if (asset.type == AssetType.video)
                          const Positioned(
                            bottom: 5,
                            right: 5,
                            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                          ),
                        if (asset.duration > 0)
                          Positioned(
                            bottom: 5,
                            left: 5,
                            child: Text(
                                "${(asset.duration / 60).floor()}:${(asset.duration % 60).toString().padLeft(2, '0')}",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                          ),
                        if (_isMultipleMode)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: isSelected
                                  ? Center(child: Text("$selectionIndex", style: const TextStyle(color: Colors.white, fontSize: 12)))
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}