import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/nguonc_api.dart';
import '../data/local_store.dart';
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';

final apiProvider = Provider<NguoncApi>((ref) => NguoncApi());

/// storeProvider được override ở main sau khi init().
final storeProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

// --- Home rows ---
final latestProvider =
    FutureProvider<Paginated<Movie>>((ref) => ref.read(apiProvider).latest());

final typeRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, type) async => (await ref.read(apiProvider).listByType(type)).items);

final genreRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, slug) async => (await ref.read(apiProvider).byGenre(slug)).items);

// --- Detail ---
final detailProvider = FutureProvider.family<MovieDetail, String>(
    (ref, slug) => ref.read(apiProvider).detail(slug));

// --- Search ---
final searchProvider = FutureProvider.family<List<Movie>, String>((ref, q) async {
  if (q.trim().length < 2) return [];
  return ref.read(apiProvider).search(q.trim());
});

// --- Browse (phân trang, cuộn vô tận) ---
class BrowseQuery {
  final String kind; // 'type' | 'genre' | 'country' | 'year'
  final String value;
  const BrowseQuery(this.kind, this.value);
  @override
  bool operator ==(Object o) => o is BrowseQuery && o.kind == kind && o.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
}

class BrowseState {
  final List<Movie> items;
  final int page, totalPage;
  final bool loading;
  BrowseState({required this.items, required this.page, required this.totalPage, required this.loading});
}

class BrowseNotifier extends StateNotifier<BrowseState> {
  final NguoncApi api;
  final BrowseQuery q;
  BrowseNotifier(this.api, this.q)
      : super(BrowseState(items: [], page: 0, totalPage: 1, loading: false)) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (state.loading || state.page >= state.totalPage) return;
    state = BrowseState(items: state.items, page: state.page, totalPage: state.totalPage, loading: true);
    final next = state.page + 1;
    Paginated<Movie> res;
    try {
      switch (q.kind) {
        case 'type': res = await api.listByType(q.value, page: next); break;
        case 'genre': res = await api.byGenre(q.value, page: next); break;
        case 'country': res = await api.byCountry(q.value, page: next); break;
        default: res = await api.byYear(q.value, page: next);
      }
    } catch (_) {
      state = BrowseState(items: state.items, page: state.page, totalPage: state.totalPage, loading: false);
      return;
    }
    state = BrowseState(items: [...state.items, ...res.items], page: next, totalPage: res.totalPage, loading: false);
  }
}

final browseProvider = StateNotifierProvider.family<BrowseNotifier, BrowseState, BrowseQuery>(
    (ref, q) => BrowseNotifier(ref.read(apiProvider), q));
