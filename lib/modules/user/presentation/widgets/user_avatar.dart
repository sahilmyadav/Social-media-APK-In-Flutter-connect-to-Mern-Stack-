import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;

  const UserAvatar({super.key, this.imageUrl, this.radius = 40});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius + 2,
      backgroundColor: Colors.grey[300], // Border effect
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImageProvider("https://clikkme.in$imageUrl") // Prepend base URL
            : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(Icons.person, size: radius, color: Colors.grey)
            : null,
      ),
    );
  }
}