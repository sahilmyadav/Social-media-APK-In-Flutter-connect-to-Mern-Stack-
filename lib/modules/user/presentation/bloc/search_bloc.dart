import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/search_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../../feed/domain/entities/post_entity.dart';

// Events
abstract class SearchEvent {}
class LoadExplore extends SearchEvent {}
class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged(this.query);
}
class ClearSearch extends SearchEvent {} // New Event

// States
abstract class SearchState {}
class SearchInitial extends SearchState {} // Loading Explore
class ExploreLoaded extends SearchState { final List<PostEntity> posts; ExploreLoaded(this.posts); }
class SearchLoading extends SearchState {} // Searching users
class SearchResultsLoaded extends SearchState { final List<UserEntity> users; SearchResultsLoaded(this.users); }
class SearchError extends SearchState { final String message; SearchError(this.message); }

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository repository;

  SearchBloc(this.repository) : super(SearchInitial()) {

    // 1. Load Explore Grid
    on<LoadExplore>((event, emit) async {
      emit(SearchInitial()); // Show skeleton
      try {
        final posts = await repository.getExploreFeed();
        emit(ExploreLoaded(posts));
      } catch (e) {
        emit(SearchError("Failed to load explore feed"));
      }
    });

    // 2. Handle Search Typing
    on<SearchQueryChanged>((event, emit) async {
      if (event.query.trim().isEmpty) {
        add(LoadExplore()); // Revert to explore if empty
        return;
      }

      emit(SearchLoading());
      try {
        final users = await repository.searchUsers(event.query);
        emit(SearchResultsLoaded(users));
      } catch (e) {
        emit(SearchError("Search failed: ${e.toString()}"));
      }
    });

    // 3. Clear Search
    on<ClearSearch>((event, emit) {
      add(LoadExplore());
    });
  }
}