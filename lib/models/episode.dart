class Episode {
  final String name, slug, embed;
  Episode({required this.name, required this.slug, required this.embed});
  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        embed: (j['embed'] ?? '').toString(),
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
