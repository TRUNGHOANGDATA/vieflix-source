class Movie {
  final String name, slug, originalName, thumbUrl, posterUrl, description;
  final String quality, language, currentEpisode;
  final int totalEpisodes;
  final List<String> genres; // dùng cho lọc Yêu thích (lưu khi thêm yêu thích)

  Movie({
    required this.name, required this.slug, required this.originalName,
    required this.thumbUrl, required this.posterUrl, required this.description,
    required this.quality, required this.language, required this.currentEpisode,
    required this.totalEpisodes, this.genres = const [],
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
        totalEpisodes: (j['total_episodes'] is int)
            ? j['total_episodes']
            : int.tryParse('${j['total_episodes']}') ?? 0,
        genres: (j['genres'] is List)
            ? (j['genres'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}
