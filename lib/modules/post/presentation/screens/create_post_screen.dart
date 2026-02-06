import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/upload_bloc.dart';

class CreatePostScreen extends StatefulWidget {
  final File imageFile;
  const CreatePostScreen({super.key, required this.imageFile});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Post"),
        actions: [
          TextButton(
            onPressed: () {
              context.read<UploadBloc>().add(
                SubmitPost([widget.imageFile], _captionController.text),
              );
            },
            child: const Text("Share", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: BlocListener<UploadBloc, UploadState>(
        listener: (context, state) {
          if (state is UploadSuccess) {
            Navigator.of(context).popUntil((route) => route.isFirst); // Go back to Feed
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posted!")));
          }
        },
        child: Column(
          children: [
            // Preview & Caption Row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.file(widget.imageFile, width: 50, height: 50, fit: BoxFit.cover),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        hintText: "Write a caption...",
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const ListTile(title: Text("Tag People"), trailing: Icon(Icons.arrow_forward_ios, size: 16)),
            const Divider(),
            const ListTile(title: Text("Add Location"), trailing: Icon(Icons.arrow_forward_ios, size: 16)),
          ],
        ),
      ),
    );
  }
}