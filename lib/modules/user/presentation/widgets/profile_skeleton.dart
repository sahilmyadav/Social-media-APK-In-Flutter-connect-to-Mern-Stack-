import 'package:flutter/material.dart';

class ProfileSkeleton extends StatefulWidget {
  const ProfileSkeleton({super.key});

  @override
  State<ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<ProfileSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _colorAnimation = ColorTween(begin: Colors.grey[800], end: Colors.grey[600]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        final color = Theme.of(context).brightness == Brightness.dark
            ? _colorAnimation.value
            : Colors.grey[300];

        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header (Cover + Avatar)
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(height: 140, width: double.infinity, color: color),
                    Positioned(
                      bottom: -50,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
                        child: CircleAvatar(radius: 50, backgroundColor: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                // Name
                _buildBox(color, 150, 24),
                const SizedBox(height: 8),
                _buildBox(color, 100, 14),
                const SizedBox(height: 20),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(child: _buildBox(color, double.infinity, 40)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildBox(color, double.infinity, 40)),
                      const SizedBox(width: 10),
                      _buildBox(color, 40, 40),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [_buildBox(color, 30, 20), const SizedBox(height: 5), _buildBox(color, 50, 12)]),
                    Column(children: [_buildBox(color, 30, 20), const SizedBox(height: 5), _buildBox(color, 50, 12)]),
                    Column(children: [_buildBox(color, 30, 20), const SizedBox(height: 5), _buildBox(color, 50, 12)]),
                  ],
                ),
                const SizedBox(height: 20),

                // Bio
                _buildBox(color, 250, 12),
                const SizedBox(height: 4),
                _buildBox(color, 200, 12),

                const SizedBox(height: 20),

                // Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1),
                  itemCount: 9,
                  itemBuilder: (_, __) => Container(color: color),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBox(Color? color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}