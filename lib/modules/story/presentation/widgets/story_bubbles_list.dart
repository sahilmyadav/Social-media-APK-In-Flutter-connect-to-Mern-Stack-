import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';
import '../../domain/entities/story_entity.dart';
import '../bloc/story_bloc.dart';
import '../screens/story_view_screen.dart';
import '../screens/story_upload_screen.dart';
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
                  return _buildMyStoryBubble(context, state);
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
              children: [_buildAddStoryButton(context)],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildMyStoryBubble(BuildContext context, StoryState state) {
    if (state is StoryLoaded && state.myStories.isNotEmpty) {
      // Show My Story with Ring
      // Show My Story with Ring
      // We need to construct a pseudo-StoryFeedEntity or handle it.
      // StoryViewScreen expects `StoryFeedEntity` (which has user and list of stories).

      final myStoryFeed = StoryFeedEntity(
        user: currentUser!,
        stories: state.myStories,
        hasUnseen: false, // My stories are always seen by me? Or check logic.
      );

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<StoryBloc>(),
                child: StoryViewScreen(
                  // OLD CODE:
                  // initialStory: myStoryFeed,
                  // NEW CODE:
                  storiesFeed: [myStoryFeed],
                  initialUserIndex: 0,
                ),
              ),
            ),
          );
        },
        onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Delete All Stories"),
              content: const Text(
                  "Are you sure you want to delete all your stories?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<StoryBloc>().add(DeleteAllStoriesEvent());
                  },
                  child:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
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
                  gradient: myStoryFeed.hasUnseen
                      ? const LinearGradient(
                          colors: [Colors.purple, Colors.orange])
                      : const LinearGradient(
                          colors: [Colors.grey, Colors.grey]),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: UserAvatar(
                      imageUrl: currentUser?.profilePicture, radius: 32),
                ),
              ),
              const SizedBox(height: 5),
              const Text("Your Story", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      return _buildAddStoryButton(context);
    }
  }

  Widget _buildAddStoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<StoryBloc>(),
              child: const StoryUploadScreen(),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Stack(
              children: [
                UserAvatar(imageUrl: currentUser?.profilePicture, radius: 35),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text("Your Story", style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryBubble(BuildContext context, storyData) {
    return GestureDetector(
      onTap: () {
        // We need access to the full feed here.
        // Since this method is separate, we might need to pass `state` or `feed` to `_buildStoryBubble`.
        // However, `_buildStoryBubble` takes `storyData`.
        // We can't access `state.feed` directly here unless we change the signature.
        // But wait, `itemBuilder` calls this.
        // Actually, checking the code, `_buildStoryBubble` is called inside `BlocBuilder`.
        // I need to change `_buildStoryBubble` signature to accept `feed` and `index`.

        // Let's assume I can't change the signature easily in `replace_file_content` without seeing the whole file call site.
        // But I CAN see the call site in previous `view_file` (Line 30).
        // It calls `_buildStoryBubble(context, storyData)`.

        // I will just use `feed` from the Bloc? No, that's not clean.
        // Best way is to access the Bloc state again?
        final storyBloc = context.read<StoryBloc>();
        List<StoryFeedEntity> currentFeed = [];
        if (storyBloc.state is StoryLoaded) {
          currentFeed = (storyBloc.state as StoryLoaded).feed;
        }

        final indexInFeed = currentFeed.indexOf(storyData);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<StoryBloc>(),
              child: StoryViewScreen(
                // OLD CODE:
                // initialStory: storyData,
                // NEW CODE:
                storiesFeed: currentFeed,
                initialUserIndex: indexInFeed != -1 ? indexInFeed : 0,
              ),
            ),
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
                    ? const LinearGradient(
                        colors: [Colors.purple, Colors.orange])
                    : const LinearGradient(colors: [Colors.grey, Colors.grey]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: UserAvatar(
                    imageUrl: storyData.user.profilePicture, radius: 32),
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
