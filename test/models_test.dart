import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';

void main() {
  test('Movie.fromJson parse đúng field cơ bản', () {
    final m = Movie.fromJson({
      'name': 'Yêu Tinh', 'slug': 'yeu-tinh-goblin',
      'original_name': 'Goblin',
      'thumb_url': 'http://t/thumb.jpg', 'poster_url': 'http://t/poster.jpg',
      'description': 'mô tả', 'total_episodes': 16,
      'current_episode': 'Hoàn tất (16/16)', 'quality': 'HD',
      'language': 'Vietsub',
    });
    expect(m.name, 'Yêu Tinh');
    expect(m.slug, 'yeu-tinh-goblin');
    expect(m.totalEpisodes, 16);
    expect(m.quality, 'HD');
  });

  test('MovieDetail.fromJson bóc category thành genres/countries/year và servers', () {
    final d = MovieDetail.fromJson({
      'name': 'Phim A', 'slug': 'phim-a',
      'original_name': 'A', 'thumb_url': 't', 'poster_url': 'p',
      'description': 'd', 'total_episodes': 1, 'current_episode': 'Full',
      'quality': 'HD', 'language': 'Vietsub',
      'director': 'Đạo diễn X', 'casts': 'A, B',
      'category': {
        '1': {'group': {'id': '1', 'name': 'Định dạng'}, 'list': [{'id': '1', 'name': 'Phim lẻ'}]},
        '2': {'group': {'id': '2', 'name': 'Thể loại'}, 'list': [{'id': '10', 'name': 'Hành Động'}, {'id': '11', 'name': 'Tâm Lý'}]},
        '3': {'group': {'id': '3', 'name': 'Năm'}, 'list': [{'id': '2024', 'name': '2024'}]},
        '4': {'group': {'id': '4', 'name': 'Quốc gia'}, 'list': [{'id': '5', 'name': 'Hàn Quốc'}]},
      },
      'episodes': [
        {'server_name': 'Vietsub #1', 'items': [
          {'name': '1', 'slug': 'tap-1', 'embed': 'http://e/1'},
          {'name': '2', 'slug': 'tap-2', 'embed': 'http://e/2'},
        ]},
      ],
    });
    expect(d.director, 'Đạo diễn X');
    expect(d.year, '2024');
    expect(d.genres.map((e) => e.name), containsAll(['Hành Động', 'Tâm Lý']));
    expect(d.countries.first.name, 'Hàn Quốc');
    expect(d.servers.first.serverName, 'Vietsub #1');
    expect(d.servers.first.items.length, 2);
    expect(d.servers.first.items.first.embed, 'http://e/1');
  });

  group('qualityTag - lọc chất lượng chung cho cả hai nguồn', () {
    Movie q(String quality) => Movie(
          name: 'x', slug: 'x', originalName: '', thumbUrl: '', posterUrl: '',
          description: '', quality: quality, language: '', currentEpisode: '',
          totalEpisodes: 0,
        );
    test('gom về 3 mức, không rõ thì để rỗng', () {
      expect(q('FHD').qualityTag, 'fhd');
      expect(q('1080p').qualityTag, 'fhd');
      expect(q('Bluray').qualityTag, 'fhd');
      expect(q('HD').qualityTag, 'hd');       // nguonc hay ghi HD
      expect(q('HDRip').qualityTag, 'hd');
      expect(q('720p').qualityTag, 'hd');
      expect(q('SD').qualityTag, 'sd');
      expect(q('CAM').qualityTag, 'sd');
      expect(q('').qualityTag, '');
      expect(q('Đang cập nhật').qualityTag, '');
    });
  });
}
