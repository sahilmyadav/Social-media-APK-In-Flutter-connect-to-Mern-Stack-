import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import '../modules/feed/presentation/screens/feed_screen.dart';
import '../modules/post/presentation/screens/media_picker_screen.dart';
import '../modules/user/presentation/screens/profile_screen.dart';
import '../modules/user/presentation/screens/search_screen.dart';
import '../modules/reels/presentation/screens/reels_screen.dart';
import '../modules/user/presentation/bloc/profile_bloc.dart';
import '../modules/user/presentation/bloc/search_bloc.dart';
import '../modules/reels/presentation/bloc/reels_bloc.dart';
import '../injection_container.dart'; // Needed for sl()

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // We initialize pages in a method to ensure 'sl' is ready
  List<Widget> _buildPages() {
    return [
      const FeedScreen(), // FeedScreen already has its own provider

      // FIX: Provide SearchBloc
      BlocProvider(
        create: (_) => sl<SearchBloc>(),
        child: const SearchScreen(),
      ),

      const SizedBox(), // Placeholder for Add

      // FIX: Provide ReelsBloc
      BlocProvider(
        create: (_) => sl<ReelsBloc>(),
        child: const ReelsScreen(),
      ),

      // FIX: Provide ProfileBloc (Solves your crash)
      BlocProvider(
        create: (_) => sl<ProfileBloc>(),
        child: const ProfileScreen(userId: "me"),
      ),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MediaPickerScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = Colors.grey;
    final pages = _buildPages();

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: isDark ? Colors.black : Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: inactiveColor),
            activeIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: activeColor),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: inactiveColor),
            activeIcon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: activeColor),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: inactiveColor, size: 32),
            activeIcon: HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: activeColor, size: 32),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: inactiveColor),
            activeIcon: HugeIcon(icon: HugeIcons.strokeRoundedVideoReplay, color: activeColor),
            label: 'Reels',
          ),
          BottomNavigationBarItem(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: inactiveColor),
            activeIcon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: activeColor),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}