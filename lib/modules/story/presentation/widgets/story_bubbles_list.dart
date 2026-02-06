import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';
import '../bloc/story_bloc.dart';
import '../screens/story_view_screen.dart';
import '../../../../modules/user/presentation/widgets/user_avatar.dart';

class StoryBubblesList extends StatelessWidget {
  final UserEntity? currentUser;

  const StoryBubblesList({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: BlocBuilder<StoryBloc, StoryState>(
        builder: (context, state) {
          if (state is StoryLoaded) {
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.feed.length + 1, // +1 for "My Story" add button
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildAddStory(context);
                }
                final storyData = state.feed[index - 1];
                return _buildStoryBubble(context, storyData);
              },
            );
          }
          // Show Add Story button even if feed is loading/empty, using currentUser
          if (state is StoryInitial || state is StoryLoading) {
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [_buildAddStory(context)],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildAddStory(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            children: [
              // FIX: Use currentUser profile picture if available
              UserAvatar(
                  imageUrl: currentUser?.profilePicture,
                  radius: 35
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Your Story", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStoryBubble(BuildContext context, storyData) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewScreen(initialStory: storyData),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: storyData.hasUnseen
                    ? const LinearGradient(colors: [Colors.purple, Colors.orange])
                    : const LinearGradient(colors: [Colors.grey, Colors.grey]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: UserAvatar(imageUrl: storyData.user.profilePicture, radius: 32),
              ),
            ),
            const SizedBox(height: 5),
            Text(storyData.user.username, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}