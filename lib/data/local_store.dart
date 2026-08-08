import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class WatchProgress {
  final String slug, name, poster, server, episodeSlug, episodeName;
  final int updatedAt;
  WatchProgress({
    required this.slug, required this.name, required this.poster,
    required this.server, required this.episodeSlug,
    required this.episodeName, required this.updatedAt,
  });
  Map<String, dynamic> toJson() => {
        'slug': slug, 'name': name, 'poster': poster,
        'server': server, 'episodeSlug': episodeSlug,
        'episodeName': episodeName, 'updatedAt': updatedAt,
      };
  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        slug: (j['slug'] ?? '').toString(),
        name: (j['name'] ?? j['slug'] ?? '').toString(),
        poster: (j['poster'] ?? '').toString(),
        server: (j['server'] ?? '').toString(),
        episodeSlug: (j['episodeSlug'] ?? '').toString(),
        episodeName: (j['episodeName'] ?? '').toString(),
        updatedAt: (j['updatedAt'] is int) ? j['updatedAt'] : 0,
      );
}

class LocalStore {
  static const _kFav = 'favorites_v1';
  static const _kProg = 'progress_v1';
  static const _maxProgress = 30; // Giữ 30 phim xem gần nhất (nhẹ cho TV)
  late SharedPreferences _p;
  final List<Movie> _favorites = [];
  final Map<String, WatchProgress> _progress = {};

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _favorites
      ..clear()
      ..addAll(((jsonDecode(_p.getString(_kFav) ?? '[]')) as List)
          .map((e) => Movie.fromJson(_favFromStored(e))));
    _progress.clear();
    final pm = (jsonDecode(_p.getString(_kProg) ?? '{}')) as Map<String, dynamic>;
    pm.forEach((k, v) => _progress[k] = WatchProgress.fromJson(v as Map<String, dynamic>));
  }

  // Chỉ lưu field cần cho card để không phụ thuộc dữ liệu đầy đủ
  Map<String, dynamic> _favToStored(Movie m) => {
        'name': m.name, 'slug': m.slug, 'poster_url': m.posterUrl,
        'thumb_url': m.thumbUrl, 'quality': m.quality,
        'current_episode': m.currentEpisode, 'total_episodes': m.totalEpisodes,
        'genres': m.genres,
      };
  Map<String, dynamic> _favFromStored(dynamic e) => (e as Map).cast<String, dynamic>();

  List<Movie> get favorites => List.unmodifiable(_favorites);
  bool isFavorite(String slug) => _favorites.any((m) => m.slug == slug);

  Future<void> toggleFavorite(Movie m) async {
    if (isFavorite(m.slug)) {
      _favorites.removeWhere((x) => x.slug == m.slug);
    } else {
      _favorites.insert(0, m);
    }
    await _p.setString(_kFav, jsonEncode(_favorites.map(_favToStored).toList()));
  }

  Future<void> saveProgress({
    required String slug, required String server,
    required String episodeSlug, required String episodeName,
    String name = '', String poster = '',
  }) async {
    _progress[slug] = WatchProgress(
      slug: slug, name: name.isNotEmpty ? name : slug, poster: poster,
      server: server, episodeSlug: episodeSlug,
      episodeName: episodeName, updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _capProgress();
    await _saveProgress();
  }

  Future<void> removeProgress(String slug) async {
    _progress.remove(slug);
    await _saveProgress();
  }

  void _capProgress() {
    if (_progress.length <= _maxProgress) return;
    final sorted = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final keep = sorted.take(_maxProgress).map((e) => e.slug).toSet();
    _progress.removeWhere((k, v) => !keep.contains(k));
  }

  Future<void> _saveProgress() async {
    await _p.setString(_kProg,
        jsonEncode(_progress.map((k, v) => MapEntry(k, v.toJson()))));
  }

  WatchProgress? progressFor(String slug) => _progress[slug];

  List<WatchProgress> get continueWatching {
    final list = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
