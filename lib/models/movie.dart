class Movie {
  final String name, slug, originalName, thumbUrl, posterUrl, description;
  final String quality, language, currentEpisode;
  final String year; // dùng để nhận ra cùng một phim giữa hai nguồn
  final int totalEpisodes;
  final List<String> genres; // dùng cho lọc Yêu thích (lưu khi thêm yêu thích)

  Movie({
    required this.name, required this.slug, required this.originalName,
    required this.thumbUrl, required this.posterUrl, required this.description,
    required this.quality, required this.language, required this.currentEpisode,
    required this.totalEpisodes, this.year = '', this.genres = const [],
  });

  // Loại tiếng suy ra từ trường `language` (vd "Vietsub + Thuyết Minh")
  bool get hasThuyetMinh {
    final l = language.toLowerCase();
    return l.contains('thuyết minh') || l.contains('thuyet minh') || l.contains('t.minh');
  }

  bool get hasLongTieng {
    final l = language.toLowerCase();
    return l.contains('lồng tiếng') || l.contains('long tieng');
  }

  bool get hasPhuDe {
    final l = language.toLowerCase();
    return l.contains('vietsub') || l.contains('phụ đề') || l.contains('phu de') || l.contains('sub');
  }

  /// Chất lượng rút về 3 mức để lọc được chung cho cả hai nguồn (nguonc ghi
  /// 'HD'/'HDRip', phimapi ghi 'FHD'/'SD'/'CAM'...). Rỗng = không rõ.
  String get qualityTag {
    final q = quality.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (q.isEmpty) return '';
    if (q.contains('fhd') || q.contains('1080') || q.contains('bluray') || q.contains('4k') || q.contains('2160')) {
      return 'fhd';
    }
    if (q.contains('hd') || q.contains('720')) return 'hd';
    if (q.contains('sd') || q.contains('cam') || q.contains('ts') || q.contains('480') || q.contains('360')) {
      return 'sd';
    }
    return '';
  }

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        originalName: (j['original_name'] ?? '').toString(),
        thumbUrl: (j['thumb_url'] ?? '').toString(),
        posterUrl: (j['poster_url'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        quality: (j['quality'] ?? '').toString(),
        language: (j['language'] ?? '').toString(),
        currentEpisode: (j['current_episode'] ?? '').toString(),
        year: (j['year'] ?? '').toString(),
        totalEpisodes: (j['total_episodes'] is int)
            ? j['total_episodes']
            : int.tryParse('${j['total_episodes']}') ?? 0,
        genres: (j['genres'] is List)
            ? (j['genres'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}
