import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_bloc.dart';

class NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const NotificationTile({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    String avatarUrl = notification.sender.profilePicture ?? "";
    if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      avatarUrl = "https://clikkme.in$avatarUrl";
    }

    bool isLive = notification.type == 'live_started';
    bool isFollow = notification.type == 'follow';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : (isDark ? const Color(0xFF1E1E1E) : Colors.blue.withOpacity(0.05)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isLive ? Border.all(color: Colors.redAccent, width: 2) : null,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: (avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: (avatarUrl.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                ),
                if (isLive)
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_active, size: 14, color: Colors.black),
                    ),
                  )
                else if (isFollow)
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white, shape: BoxShape.circle),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, size: 14, color: Colors.green),
                    ),
                  )
              ],
            ),
            const SizedBox(width: 14),

            // 2. Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(color: textColor, fontSize: 14, height: 1.3),
                      children: [
                        TextSpan(
                          text: notification.sender.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: " ${notification.message.replaceAll(notification.sender.username, '').trim()}",
                          style: TextStyle(color: textColor.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(DateTime.parse(notification.createdAt), locale: 'en_short'),
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 3. Trailing Action
            _buildTrailingWidget(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(BuildContext context, bool isDark) {
    if (notification.type == 'follow') {
      // CHECK: If manually followed back OR if sender object says we are following
      bool isFollowing = notification.isFollowedBack || notification.sender.isFollowing;

      if (isFollowing) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "Following",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.white : Colors.black),
          ),
        );
      }

      return ElevatedButton(
        onPressed: () {
          context.read<NotificationBloc>().add(FollowBackEvent(notification.sender.id, notification.id));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5DD3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          minimumSize: const Size(0, 34),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14),
            const SizedBox(width: 4),
            Text("Follow Back", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
    }

    // Thumbnail logic for likes/comments
    if ((notification.type == 'like' || notification.type == 'comment') && notification.thumbnail != null) {
      String thumbUrl = notification.thumbnail!;
      if (!thumbUrl.startsWith('http')) thumbUrl = "https://clikkme.in$thumbUrl";

      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: DecorationImage(image: CachedNetworkImageProvider(thumbUrl), fit: BoxFit.cover),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}