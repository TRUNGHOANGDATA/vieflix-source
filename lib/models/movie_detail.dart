import 'movie.dart';
import 'episode.dart';

class CategoryItem {
  final String name, slug;
  CategoryItem({required this.name, required this.slug});
}

class MovieDetail {
  final Movie base;
  final String? director, casts, year;
  final List<CategoryItem> genres, countries;
  final List<ServerGroup> servers;

  MovieDetail({
    required this.base, this.director, this.casts, this.year,
    required this.genres, required this.countries, required this.servers,
  });

  String get name => base.name;
  String get slug => base.slug;
  String get posterUrl => base.posterUrl;
  String get thumbUrl => base.thumbUrl;
  String get description => base.description;

  factory MovieDetail.fromJson(Map<String, dynamic> j) {
    final cat = (j['category'] as Map?)?.cast<String, dynamic>() ?? {};
    List<CategoryItem> pick(String groupName) {
      for (final v in cat.values) {
        final g = (v as Map)['group'] as Map?;
        if (g != null && g['name'] == groupName) {
          return ((v['list'] as List?) ?? [])
              .map((e) => CategoryItem(
                    name: (e['name'] ?? '').toString(),
                    slug: _slugify((e['name'] ?? '').toString()),
                  ))
              .toList();
        }
      }
      return [];
    }

    final years = pick('Năm');
    return MovieDetail(
      base: Movie.fromJson(j),
      director: (j['director'] ?? '').toString().isEmpty ? null : j['director'].toString(),
      casts: (j['casts'] ?? '').toString().isEmpty ? null : j['casts'].toString(),
      year: years.isEmpty ? null : years.first.name,
      genres: pick('Thể loại'),
      countries: pick('Quốc gia'),
      servers: ((j['episodes'] as List?) ?? [])
          .map((e) => ServerGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

String _slugify(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to   = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    buf.write(i >= 0 ? to[i] : c);
  }
  return buf.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
