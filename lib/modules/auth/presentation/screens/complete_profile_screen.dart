import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../presentation/main_screen.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../domain/auth_repository.dart'; // Added
import '../../../../injection_container.dart'; // Added
import 'package:permission_handler/permission_handler.dart'; // Added for openAppSettings

class CompleteProfileScreen extends StatefulWidget {
  final String suggestedUsername;
  const CompleteProfileScreen({super.key, required this.suggestedUsername});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late TextEditingController _usernameController;
  final TextEditingController _bioController = TextEditingController();
  File? _imageFile;
  File? _coverFile;
  Timer? _debounce;
  bool _isUsernameValid = true;

  // Interests Data
  final List<String> _allInterests = [
    "Photography",
    "Travel",
    "Music",
    "Fitness",
    "Gaming",
    "Cooking",
    "Art",
    "Design",
    "Tech",
    "Science",
    "Fashion",
    "Writing",
    "Reading",
    "Movies",
    "Dancing",
    "Sports",
    "Nature",
    "Pets",
    "Cars",
    "Business",
    "Investing",
    "DIY",
    "Gardening",
    "History",
    "Space",
    "Comedy",
    "Magic",
    "Anime",
    "Comics",
    "Coding"
  ];
  final Set<String> _selectedInterests = {};
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.suggestedUsername);
    // Perform initial check
    context
        .read<AuthBloc>()
        .add(CheckUsernameRequested(widget.suggestedUsername));
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.isNotEmpty) {
        context.read<AuthBloc>().add(CheckUsernameRequested(value));
      }
    });
  }

  // REFRESH LOGIC
  void _refreshUsername() {
    String base = _usernameController.text.replaceAll(RegExp(r'[0-9]'), '');
    if (base.isEmpty) base = "user";
    String newSuffix = Random().nextInt(9999).toString();
    String newName = "$base$newSuffix";
    _usernameController.text = newName;
    context.read<AuthBloc>().add(CheckUsernameRequested(newName));
  }

  // --- SAFELY HANDLED IMAGE LOGIC ---
  Future<void> _pickImage(bool isCover) async {
    // --- Permission Check ---
    final repo = sl<AuthRepository>();
    final hasPermission = await repo.requestStoragePermission();

    if (!hasPermission) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File? croppedFile = await _cropImage(File(pickedFile.path), isCover);

        if (croppedFile != null) {
          File? compressedFile = await _compressFile(croppedFile);

          if (compressedFile != null && mounted) {
            setState(() {
              if (isCover) {
                _coverFile = compressedFile;
              } else {
                _imageFile = compressedFile;
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(
            context, "Failed to load image: ${e.toString()}");
      }
    }
  }

  Future<File?> _cropImage(File imageFile, bool isCover) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        // Insta-style 1:1 for profile, 16:9 for cover
        aspectRatio: isCover
            ? const CropAspectRatio(ratioX: 16, ratioY: 9)
            : const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isCover ? 'Crop Cover Photo' : 'Crop Profile Picture',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: isCover
                ? CropAspectRatioPreset.ratio16x9
                : CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: isCover ? 'Crop Cover Photo' : 'Crop Profile Picture',
          ),
        ],
      );
      if (croppedFile != null) return File(croppedFile.path);
    } catch (e) {
      // Fallback: Return original if crop fails or activity missing
      debugPrint("Crop Error: $e");
      return imageFile;
    }
    return null;
  }

  Future<File?> _compressFile(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          "${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg";
      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      return file; // Return original if compression fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Variables
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = Colors.grey;
    final inputFillColor =
        isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final placeholderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    // Displayed Interests
    final displayedInterests =
        _isExpanded ? _allInterests : _allInterests.take(10).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false);
          } else if (state is AuthFailure) {
            SnackbarUtils.showError(context, state.error);
          }
        },
        builder: (context, state) {
          if (state is AuthUsernameChecked) {
            _isUsernameValid = state.isAvailable;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // ... imports ...
// (Keep existing imports and state logic)

                // ... inside build method ...

                // 1. Cover Photo & Avatar Area
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Cover Photo
                    GestureDetector(
                      onTap: () => _pickImage(true),
                      behavior: HitTestBehavior
                          .opaque, // FIX: Tap anywhere in container
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          gradient: _coverFile == null
                              ? const LinearGradient(colors: [
                                  Color(0xFFE1306C),
                                  Color(0xFFF77737)
                                ])
                              : null,
                          image: _coverFile != null
                              ? DecorationImage(
                                  image: FileImage(_coverFile!),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _coverFile == null
                            ? const Center(
                                child: Text("Click to add cover photo",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)))
                            : null,
                      ),
                    ),

                    // Avatar Overlap
                    Positioned(
                      bottom: -50,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => _pickImage(false),
                        behavior: HitTestBehavior
                            .opaque, // FIX: Tap anywhere in container
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: backgroundColor, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: placeholderColor,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_outline,
                                          size: 40, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text("Add photo",
                                          style: TextStyle(
                                              fontSize: 10, color: Colors.grey))
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // ... (rest of the file remains same)
                    // Camera Badges
                    if (_imageFile == null)
                      Positioned(
                          bottom: -45,
                          left: 85,
                          child: _buildCameraBadge(isDark)),
                    if (_coverFile == null)
                      Positioned(
                          top: 110,
                          right: 20,
                          child: _buildCameraBadge(isDark)),
                  ],
                ),

                const SizedBox(height: 60),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Text("Click photos to edit",
                              style: TextStyle(
                                  color: subTextColor, fontSize: 12))),
                      const SizedBox(height: 20),

                      // Username Field
                      _buildLabel("Username", required: true, color: textColor),
                      TextField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          suffixIcon: _usernameController.text.isNotEmpty
                              ? Icon(
                                  _isUsernameValid ? Icons.check : Icons.close,
                                  color: _isUsernameValid
                                      ? Colors.green
                                      : Colors.red)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isUsernameValid
                            ? "Username is available!"
                            : "Username taken",
                        style: TextStyle(
                            color: _isUsernameValid ? Colors.green : Colors.red,
                            fontSize: 12),
                      ),

                      const SizedBox(height: 15),
                      // Suggestions Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "Suggestions for \"${_usernameController.text}\"",
                                    style: TextStyle(
                                        color: subTextColor, fontSize: 12)),
                                GestureDetector(
                                  onTap: _refreshUsername,
                                  child: const Text("Refresh",
                                      style: TextStyle(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1, 88, 99]
                                  .map((i) => GestureDetector(
                                        onTap: () {
                                          _usernameController.text =
                                              "${_usernameController.text}$i";
                                          context.read<AuthBloc>().add(
                                              CheckUsernameRequested(
                                                  _usernameController.text));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: borderColor),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check,
                                                  size: 14,
                                                  color: Colors.green),
                                              const SizedBox(width: 4),
                                              Text(
                                                  "${_usernameController.text}$i",
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: textColor)),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildLabel("Bio", required: false, color: textColor),
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Tell us about yourself...",
                          hintStyle: TextStyle(color: subTextColor),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("0/150 characters",
                          style: TextStyle(color: subTextColor, fontSize: 12)),

                      const SizedBox(height: 20),

                      // Interests Selection
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Colors.purple, size: 18),
                          const SizedBox(width: 5),
                          Text("Your Interests",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          Text(" (Optional)",
                              style: TextStyle(color: subTextColor)),
                          const Spacer(),
                          Text("${_selectedInterests.length} selected",
                              style:
                                  TextStyle(color: subTextColor, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: displayedInterests.map((interest) {
                          final isSelected =
                              _selectedInterests.contains(interest);
                          return ChoiceChip(
                            label: Text(interest),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedInterests.add(interest);
                                } else {
                                  _selectedInterests.remove(interest);
                                }
                              });
                            },
                            selectedColor: Colors.purple.withOpacity(0.2),
                            backgroundColor:
                                isDark ? const Color(0xFF262626) : Colors.white,
                            labelStyle: TextStyle(
                                color: isSelected ? Colors.purple : textColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                            shape: StadiumBorder(
                                side: BorderSide(
                                    color: isSelected
                                        ? Colors.purple
                                        : borderColor)),
                          );
                        }).toList(),
                      ),

                      if (!_isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: GestureDetector(
                            onTap: () => setState(() => _isExpanded = true),
                            child: const Text("Show more (25 more)",
                                style: TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                            ),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: (state is AuthLoading ||
                                    !_isUsernameValid)
                                ? null
                                : () {
                                    context
                                        .read<AuthBloc>()
                                        .add(CompleteProfileRequested(
                                          username: _usernameController.text,
                                          bio: _bioController.text,
                                          profilePicture: _imageFile,
                                          coverPhoto: _coverFile,
                                          interests:
                                              _selectedInterests.toList(),
                                        ));
                                  },
                            child: state is AuthLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("Complete Profile",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text,
      {required bool required, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          if (required) const Text(" *", style: TextStyle(color: Colors.red)),
          if (!required)
            const Text(" (Optional)", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCameraBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Icon(Icons.camera_alt,
          size: 16, color: isDark ? Colors.white : Colors.black),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text(
            "We need access to your photos to set your profile picture. Please enable it in settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }
}
