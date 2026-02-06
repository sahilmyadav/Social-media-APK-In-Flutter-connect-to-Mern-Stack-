import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../injection_container.dart';
import '../../../../../core/network/api_client.dart';
import '../../data/repositories/reels_repository.dart';
import '../bloc/reels_bloc.dart';
import '../widgets/reel_player_item.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReelsBloc(sl<ReelsRepository>())..add(FetchReels()),
      child: const ReelsView(),
    );
  }
}

class ReelsView extends StatelessWidget {
  const ReelsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<ReelsBloc, ReelsState>(
        builder: (context, state) {
          if (state is ReelsLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          } else if (state is ReelsError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
          } else if (state is ReelsLoaded) {
            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: state.reels.length,
              itemBuilder: (context, index) {
                // Ensure we pass the updated reel from the state to the item
                return ReelPlayerItem(reel: state.reels[index]);
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}