import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../injection_container.dart';
import '../../data/repositories/notification_repository.dart';
import '../bloc/notification_bloc.dart';
import '../widgets/notification_tile.dart';

import '../../../user/presentation/screens/profile_screen.dart';
import '../../../user/presentation/bloc/profile_bloc.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../user/presentation/screens/post_details_screen.dart';
import 'notification_skeleton.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc(sl<NotificationRepository>())
        ..add(LoadNotifications()),
      child: const NotificationView(),
    );
  }
}

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Notifications",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                size: 24,
                color: Colors.grey),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip(context, "All", true),
                const SizedBox(width: 10),
                BlocBuilder<NotificationBloc, NotificationState>(
                  builder: (context, state) {
                    int count = 0;
                    if (state is NotificationLoaded) count = state.unreadCount;
                    return _buildFilterChip(context, "Unread ($count)", false);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                // Handle Initial/Loading with Skeleton
                if (state is NotificationLoading ||
                    state is NotificationInitial) {
                  return const NotificationSkeleton();
                } else if (state is NotificationLoaded) {
                  if (state.notifications.isEmpty) {
                    return Center(
                        child: Text("No notifications yet",
                            style: GoogleFonts.inter(color: Colors.grey)));
                  }

                  return RefreshIndicator(
                    color: const Color(0xFF6C5DD3),
                    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                    onRefresh: () async {
                      context
                          .read<NotificationBloc>()
                          .add(RefreshNotifications());
                    },
                    child: ListView.builder(
                      itemCount: state.notifications.length,
                      itemBuilder: (context, index) {
                        final item = state.notifications[index];
                        return NotificationTile(
                          notification: item,
                          onTap: () => _handleNotificationTap(context, item),
                        );
                      },
                    ),
                  );
                } else if (state is NotificationError) {
                  return Center(child: Text(state.message));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- FIXED: Handles Dark Mode Colors Correctly ---
  Widget _buildFilterChip(BuildContext context, String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Logic: If selected -> White Text.
    // If NOT selected: Dark Mode -> White Text, Light Mode -> Black Text.
    final textColor =
        isSelected ? Colors.white : (isDark ? Colors.white : Colors.black);

    final borderColor =
        isSelected ? null : (isDark ? Colors.grey[800]! : Colors.grey.shade300);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6C5DD3) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? null : Border.all(color: borderColor!),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, dynamic item) {
    context.read<NotificationBloc>().add(MarkReadEvent(item.id));

    if (item.type == 'follow') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BlocProvider(
                    create: (_) => sl<ProfileBloc>(),
                    child: ProfileScreen(userId: item.sender.id),
                  )));
    } else if (item.type == 'like' || item.type == 'comment') {
      if (item.referenceId != null) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailsScreen(postId: item.referenceId!),
            ));
      }
    }
  }
}
