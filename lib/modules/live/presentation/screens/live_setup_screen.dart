import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hugeicons/hugeicons.dart';

import '../bloc/live_bloc.dart';
import 'live_preview_screen.dart';

class LiveSetupScreen extends StatefulWidget {
  const LiveSetupScreen({super.key});

  @override
  State<LiveSetupScreen> createState() => _LiveSetupScreenState();
}

class _LiveSetupScreenState extends State<LiveSetupScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _thumbnail;
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _thumbnail = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LiveBloc, LiveState>(
      listener: (context, state) {
        if (state is LiveStreamCreated) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LivePreviewScreen(stream: state.stream),
            ),
          );
        } else if (state is LiveError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("Go Live",
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      const HugeIcon(
                          icon: HugeIcons.strokeRoundedStar,
                          color: Color(0xFF6B4EFF),
                          size: 20),
                      "Stream Details"),
                  const Text(
                      "Add information about your live stream to help viewers find you",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),

                  // Title Input
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "Title *",
                      hintText: "What's your live stream about?",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    maxLength: 100,
                    validator: (value) => value == null || value.isEmpty
                        ? "Please enter a title"
                        : null,
                  ),
                  const SizedBox(height: 10),

                  // Description Input
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: "Description (Optional)",
                      hintText: "Tell viewers what to expect...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 20),

                  // Key Features / Tips (Side Panel in screenshot, here inline for mobile)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTipRow(Icons.lightbulb_outline, "Good Lighting",
                            "Face a window or use soft lighting."),
                        const SizedBox(height: 10),
                        _buildTipRow(Icons.wifi, "Stable Connection",
                            "Use WiFi for best results."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Thumbnail Picker
                  _buildSectionHeader(
                      const Icon(Icons.image,
                          size: 20, color: Color(0xFF6B4EFF)),
                      "Cover Photo (Optional)"),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey[300]!, style: BorderStyle.solid),
                        image: _thumbnail != null
                            ? DecorationImage(
                                image: FileImage(_thumbnail!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _thumbnail == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text("Click to upload a cover photo",
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.black)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state is LiveLoading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    context
                                        .read<LiveBloc>()
                                        .add(CreateStreamEvent(
                                          title: _titleController.text,
                                          description:
                                              _descriptionController.text,
                                          thumbnailPath: _thumbnail?.path,
                                        ));
                                  }
                                },
                          icon: state is LiveLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.bolt, color: Colors.white),
                          label: const Text("Create & Go Live",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                                0xFFFF4B6E), // Button color from screenshot
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(Widget iconWidget, String title) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ],
    );
  }

  Widget _buildTipRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        )
      ],
    );
  }
}
