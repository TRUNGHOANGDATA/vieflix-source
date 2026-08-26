class Episode {
  final String name, slug, embed;

  /// Link video trực tiếp (HLS). Chỉ nguồn phimapi có; rỗng thì phát bằng embed.
  final String m3u8;

  Episode({
    required this.name,
    required this.slug,
    required this.embed,
    this.m3u8 = '',
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        embed: (j['embed'] ?? '').toString(),
        m3u8: (j['m3u8'] ?? '').toString(),
      );
}

class ServerGroup {
  final String serverName;
  final List<Episode> items;
  ServerGroup({required this.serverName, required this.items});
  factory ServerGroup.fromJson(Map<String, dynamic> j) => ServerGroup(
        serverName: (j['server_name'] ?? '').toString(),
        items: ((j['items'] as List?) ?? [])
            .map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
