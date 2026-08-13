import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class WatchProgress {
  final String slug, name, poster, server, episodeSlug, episodeName;
  final int updatedAt;
  final double positionSeconds; // vị trí đang xem dở trong tập (giây)
  final double durationSeconds; // tổng thời lượng tập (giây), để tính % và bỏ qua nếu gần hết
  WatchProgress({
    required this.slug, required this.name, required this.poster,
    required this.server, required this.episodeSlug,
    required this.episodeName, required this.updatedAt,
    this.positionSeconds = 0, this.durationSeconds = 0,
  });
  Map<String, dynamic> toJson() => {
        'slug': slug, 'name': name, 'poster': poster,
        'server': server, 'episodeSlug': episodeSlug,
        'episodeName': episodeName, 'updatedAt': updatedAt,
        'pos': positionSeconds, 'dur': durationSeconds,
      };
  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        slug: (j['slug'] ?? '').toString(),
        name: (j['name'] ?? j['slug'] ?? '').toString(),
        poster: (j['poster'] ?? '').toString(),
        server: (j['server'] ?? '').toString(),
        episodeSlug: (j['episodeSlug'] ?? '').toString(),
        episodeName: (j['episodeName'] ?? '').toString(),
        updatedAt: (j['updatedAt'] is int) ? j['updatedAt'] : 0,
        positionSeconds: (j['pos'] is num) ? (j['pos'] as num).toDouble() : 0,
        durationSeconds: (j['dur'] is num) ? (j['dur'] as num).toDouble() : 0,
      );

  WatchProgress copyWith({double? positionSeconds, double? durationSeconds, int? updatedAt}) =>
      WatchProgress(
        slug: slug, name: name, poster: poster, server: server,
        episodeSlug: episodeSlug, episodeName: episodeName,
        updatedAt: updatedAt ?? this.updatedAt,
        positionSeconds: positionSeconds ?? this.positionSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

class LocalStore {
  static const _kFav = 'favorites_v1';
  static const _kProg = 'progress_v1';
  static const _kTmdb = 'tmdb_key';
  static const _maxProgress = 200; // Giữ 200 phim xem gần nhất
  late SharedPreferences _p;
  final List<Movie> _favorites = [];
  final Map<String, WatchProgress> _progress = {};
  File? _progressFile; // bản sao lưu trên đĩa (bền hơn SharedPreferences trên TV box)

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _favorites
      ..clear()
      ..addAll(((jsonDecode(_p.getString(_kFav) ?? '[]')) as List)
          .map((e) => Movie.fromJson(_favFromStored(e))));

    // Mở file sao lưu tiến độ.
    try {
      final dir = await getApplicationDocumentsDirectory();
      _progressFile = File('${dir.path}${Platform.pathSeparator}vieflix_progress.json');
    } catch (_) {
      _progressFile = null;
    }

    // Nạp tiến độ từ CẢ hai nguồn (SharedPreferences + file) rồi GỘP theo slug,
    // giữ bản mới hơn. Nhờ vậy dù một nguồn bị xoá/mất thì vẫn còn nguồn kia.
    _progress.clear();
    _mergeInto(_readPrefsProgress());
    _mergeInto(await _readFileProgress());
    // Ghi lại cả hai nguồn cho đồng bộ (khôi phục nguồn bị thiếu).
    await _saveProgress();
  }

  Map<String, WatchProgress> _readPrefsProgress() {
    try {
      final pm = (jsonDecode(_p.getString(_kProg) ?? '{}')) as Map<String, dynamic>;
      return pm.map((k, v) => MapEntry(k, WatchProgress.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, WatchProgress>> _readFileProgress() async {
    final f = _progressFile;
    if (f == null) return {};
    try {
      if (!await f.exists()) return {};
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) return {};
      final pm = (jsonDecode(txt)) as Map<String, dynamic>;
      return pm.map((k, v) => MapEntry(k, WatchProgress.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  // Gộp vào _progress, chỉ ghi đè nếu bản mới có updatedAt lớn hơn.
  void _mergeInto(Map<String, WatchProgress> src) {
    src.forEach((k, v) {
      final cur = _progress[k];
      if (cur == null || v.updatedAt >= cur.updatedAt) _progress[k] = v;
    });
  }

  // Chỉ lưu field cần cho card để không phụ thuộc dữ liệu đầy đủ
  Map<String, dynamic> _favToStored(Movie m) => {
        'name': m.name, 'slug': m.slug, 'poster_url': m.posterUrl,
        'thumb_url': m.thumbUrl, 'quality': m.quality,
        'current_episode': m.currentEpisode, 'total_episodes': m.totalEpisodes,
        'genres': m.genres,
      };
  Map<String, dynamic> _favFromStored(dynamic e) => (e as Map).cast<String, dynamic>();

  // --- Khóa TMDB (rating) ---
  String get tmdbKey => _p.getString(_kTmdb) ?? '';
  Future<void> setTmdbKey(String k) async => _p.setString(_kTmdb, k.trim());

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
    double positionSeconds = 0, double durationSeconds = 0,
  }) async {
    _progress[slug] = WatchProgress(
      slug: slug, name: name.isNotEmpty ? name : slug, poster: poster,
      server: server, episodeSlug: episodeSlug,
      episodeName: episodeName, updatedAt: DateTime.now().millisecondsSinceEpoch,
      positionSeconds: positionSeconds, durationSeconds: durationSeconds,
    );
    _capProgress();
    await _saveProgress();
  }

  /// Cập nhật NHẸ vị trí đang xem cho phim hiện tại (gọi định kỳ khi phát).
  /// Chỉ đụng tới entry đã có sẵn (do saveProgress tạo lúc bắt đầu xem).
  Future<void> savePosition(String slug, double positionSeconds, double durationSeconds) async {
    final cur = _progress[slug];
    if (cur == null) return;
    _progress[slug] = cur.copyWith(
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds > 0 ? durationSeconds : cur.durationSeconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
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
    final json = jsonEncode(_progress.map((k, v) => MapEntry(k, v.toJson())));
    // Ghi cả hai nơi: SharedPreferences + file sao lưu.
    try { await _p.setString(_kProg, json); } catch (_) {}
    final f = _progressFile;
    if (f != null) {
      try { await f.writeAsString(json, flush: true); } catch (_) {}
    }
  }

  WatchProgress? progressFor(String slug) => _progress[slug];

  // --- Đồng bộ giữa các máy: xuất/nhập toàn bộ "đang xem" + "yêu thích" ---

  /// Gói dữ liệu để mang qua máy khác (JSON gọn: tiến độ + phim đã lưu).
  String exportData() => jsonEncode({
        'v': 1,
        'progress': _progress.map((k, v) => MapEntry(k, v.toJson())),
        'favorites': _favorites.map(_favToStored).toList(),
      });

  /// Nhập gói dữ liệu từ máy khác và GỘP vào (giữ bản xem mới hơn, thêm phim
  /// yêu thích còn thiếu). Trả về (số mục đang xem, số phim yêu thích) đã nhận.
  Future<(int, int)> importData(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    if (data is! Map) throw const FormatException('Dữ liệu không hợp lệ');
    int pc = 0, fc = 0;

    final prog = data['progress'];
    if (prog is Map) {
      prog.forEach((k, v) {
        try {
          final wp = WatchProgress.fromJson((v as Map).cast<String, dynamic>());
          final cur = _progress[k as String];
          if (cur == null || wp.updatedAt >= cur.updatedAt) {
            _progress[k] = wp;
            pc++;
          }
        } catch (_) {}
      });
    }

    final favs = data['favorites'];
    if (favs is List) {
      for (final e in favs) {
        try {
          final m = Movie.fromJson((e as Map).cast<String, dynamic>());
          if (m.slug.isNotEmpty && !isFavorite(m.slug)) {
            _favorites.add(m);
            fc++;
          }
        } catch (_) {}
      }
    }

    _capProgress();
    await _saveProgress();
    await _p.setString(_kFav, jsonEncode(_favorites.map(_favToStored).toList()));
    return (pc, fc);
  }

  List<WatchProgress> get continueWatching {
    final list = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
