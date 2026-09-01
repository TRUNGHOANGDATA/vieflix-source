import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/data/stream_sources.dart';
import 'package:app_xem_phim/models/episode.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/paginated.dart';
import 'package:app_xem_phim/models/stream_source.dart';

Episode _e(String name, {String m3u8 = ''}) =>
    Episode(name: name, slug: name, embed: 'http://embed/$name', m3u8: m3u8);

Movie _m(String slug, {String origin = '', String year = '2026'}) => Movie(
      name: slug, slug: slug, originalName: origin,
      thumbUrl: '', posterUrl: '', description: '',
      quality: '', language: '', currentEpisode: '',
      totalEpisodes: 0, year: year,
    );

MovieDetail _d(String slug, List<ServerGroup> servers,
        {String origin = '', String year = '2026'}) =>
    MovieDetail(
      base: _m(slug, origin: origin, year: year),
      year: year, genres: [], countries: [], servers: servers,
    );

class _FakeSource implements MovieSource {
  @override
  final String id;
  final List<Movie> results;
  final Map<String, MovieDetail> details;
  final List<String> calls = [];
  _FakeSource(this.id, {this.results = const [], this.details = const {}});

  @override
  Future<List<Movie>> search(String k) async {
    calls.add('search:$k');
    return results;
  }

  @override
  Future<MovieDetail> detail(String slug) async {
    calls.add('detail:$slug');
    final d = details[slug];
    if (d == null) throw ApiException('không có');
    return d;
  }

  @override
  Future<Paginated<Movie>> latest({int page = 1}) async => throw UnimplementedError();
  @override
  Future<Paginated<Movie>> listByType(String t, {int page = 1}) async => throw UnimplementedError();
  @override
  Future<Paginated<Movie>> byGenre(String s, {int page = 1}) async => throw UnimplementedError();
  @override
  Future<Paginated<Movie>> byCountry(String s, {int page = 1}) async => throw UnimplementedError();
  @override
  Future<Paginated<Movie>> byYear(String y, {int page = 1}) async => throw UnimplementedError();
  @override
  Future<Paginated<Movie>> browse(BrowseFilter f, {int page = 1}) async => throw UnimplementedError();
}

void main() {
  group('langOfServer', () {
    test('rút đúng loại tiếng từ tên server của cả hai nguồn', () {
      expect(langOfServer('Vietsub #1'), 'Vietsub');
      expect(langOfServer('Thuyết minh #2'), 'Thuyết minh');
      expect(langOfServer('Thuyết Minh'), 'Thuyết minh');
      expect(langOfServer('Lồng Tiếng'), 'Lồng tiếng');
      expect(langOfServer('Server ABC'), 'Server ABC'); // lạ thì giữ nguyên
      expect(langOfServer('  '), 'Mặc định');
    });
  });

  group('matchEpisodeIndex', () {
    final nguonc = [_e('1'), _e('2'), _e('3')];
    final phimapi = [_e('Tập 01'), _e('Tập 02'), _e('Tập 03'), _e('Tập 04')];

    test('map theo SỐ tập chứ không theo vị trí', () {
      expect(matchEpisodeIndex(nguonc, 1, phimapi), 1);
      // Nguồn kia thiếu tập đầu -> vị trí lệch, số tập mới đúng.
      final thieu = [_e('Tập 02'), _e('Tập 03')];
      expect(matchEpisodeIndex(nguonc, 1, thieu), 0);
      expect(matchEpisodeIndex(nguonc, 2, thieu), 1);
    });

    test('nguồn kia chưa có tập đó thì trả null (không phát nhầm tập)', () {
      final it = [_e('Tập 01')];
      expect(matchEpisodeIndex(nguonc, 2, it), isNull);
      expect(matchEpisodeIndex(nguonc, 0, []), isNull);
    });

    test('phim lẻ một tập hai bên thì khớp thẳng', () {
      expect(matchEpisodeIndex([_e('Full')], 0, [_e('Tập 1')]), 0);
    });

    test('tên tập không đánh số thì đành theo vị trí', () {
      final a = [_e('Phần đầu'), _e('Phần cuối')];
      final b = [_e('Bản đẹp'), _e('Bản thường')];
      expect(matchEpisodeIndex(a, 1, b), 1);
    });
  });

  group('streamSourcesOf', () {
    test('mỗi server thành một lựa chọn, có m3u8 thì đánh dấu hls', () {
      final d = _d('pa:phim-a', [
        ServerGroup(serverName: 'Vietsub', items: [_e('Tập 01', m3u8: 'http://x.m3u8')]),
        ServerGroup(serverName: 'Thuyết Minh', items: [_e('Tập 01')]),
        ServerGroup(serverName: 'Rỗng', items: []), // server rỗng thì bỏ
      ]);
      final list = streamSourcesOf(d);
      expect(list.map((s) => s.label), ['phimapi · Vietsub', 'phimapi · Thuyết minh']);
      expect(list[0].kind, StreamKind.hls);
      expect(list[1].kind, StreamKind.embed);
      expect(list.every((s) => s.movieSlug == 'pa:phim-a'), isTrue);
    });

    test('nhãn nguồn lấy theo tiền tố slug', () {
      final d = _d('phim-a', [ServerGroup(serverName: 'Vietsub #1', items: [_e('1')])]);
      expect(streamSourcesOf(d).single.label, 'nguonc · Vietsub');
    });
  });

  group('alternateStreamSources', () {
    test('tìm cùng phim ở nguồn kia dù slug khác nhau', () async {
      final primary = _d('sep-chinh-la-than-tuong',
          [ServerGroup(serverName: 'Vietsub #1', items: [_e('1')])],
          origin: 'My Bias, My Boss');

      const otherSlug = 'pa:sep-chinh-la-than-tuong-bias-toi-sep-cua-toi';
      final other = _FakeSource(kSrcPhimApi,
          results: [
            _m('pa:phim-khac', origin: 'Something Else'),
            _m(otherSlug, origin: 'My Bias, My Boss'),
          ],
          details: {
            otherSlug: _d(otherSlug, [
              ServerGroup(serverName: 'Vietsub', items: [_e('Tập 01')]),
              ServerGroup(serverName: 'Thuyết Minh', items: [_e('Tập 01')]),
            ], origin: 'My Bias, My Boss'),
          });

      final list = await alternateStreamSources(primary: primary, others: [other]);
      expect(list.map((s) => s.label),
          ['phimapi · Vietsub', 'phimapi · Thuyết minh']);
      // Tìm bằng TÊN GỐC vì slug hai bên không giống nhau.
      expect(other.calls.first, 'search:My Bias, My Boss');
    });

    test('cùng tên nhưng khác năm thì KHÔNG nhận (tránh nhầm mùa/bản làm lại)', () async {
      final primary = _d('phim-2025', [ServerGroup(serverName: 'Vietsub', items: [_e('1')])],
          origin: 'Same Show', year: '2025');
      final other = _FakeSource(kSrcPhimApi,
          results: [_m('pa:phim-2026', origin: 'Same Show', year: '2026')]);
      expect(await alternateStreamSources(primary: primary, others: [other]), isEmpty);
    });

    test('nguồn kia không có phim / lỗi mạng thì trả rỗng, không ném lỗi', () async {
      final primary = _d('phim-a', [ServerGroup(serverName: 'Vietsub', items: [_e('1')])],
          origin: 'Only Here');
      final other = _FakeSource(kSrcPhimApi, results: []);
      expect(await alternateStreamSources(primary: primary, others: [other]), isEmpty);
    });
  });

  group('chọn nguồn mặc định', () {
    final pick = defaultSourceIndex;

    StreamSource src(String provider, String lang, StreamKind kind) => StreamSource(
          provider: provider, movieSlug: 'x', serverName: lang,
          lang: lang, kind: kind, episodes: [_e('1')],
        );

    test('THUYẾT MINH luôn thắng, kể cả khi bản kia phát thẳng nhanh hơn', () {
      // nguonc Thuyết minh (embed, chậm) vs phimapi Vietsub (hls, nhanh).
      // Ưu tiên TIẾNG cao hơn tốc độ -> phải chọn Thuyết minh.
      final list = [
        src('phimapi', 'Vietsub', StreamKind.hls),
        src('nguonc', 'Thuyết minh', StreamKind.embed),
      ];
      expect(pick(list), 1);
    });

    test('thuyết minh có link thẳng thắng thuyết minh embed', () {
      final list = [
        src('nguonc', 'Vietsub', StreamKind.embed),
        src('nguonc', 'Thuyết minh', StreamKind.embed),
        src('phimapi', 'Thuyết minh', StreamKind.hls),
      ];
      expect(pick(list), 2);
    });

    test('không có tiếng Việt thì lấy bản phát thẳng', () {
      final list = [
        src('nguonc', 'Vietsub', StreamKind.embed),
        src('phimapi', 'Vietsub', StreamKind.hls),
      ];
      expect(pick(list), 1);
    });

    test('toàn embed thì giữ nguyên thứ tự ưu tiên tiếng Việt như trước', () {
      final list = [
        src('nguonc', 'Vietsub', StreamKind.embed),
        src('nguonc', 'Thuyết minh', StreamKind.embed),
      ];
      expect(pick(list), 1);
    });
  });

  group('resumePosition', () {
    test('nguonc trả 0 — trang embed của nó tự nhớ, tua đè sẽ đá nhau', () {
      expect(
          resumePosition(
              provider: kSrcNguonc, positionSeconds: 600, durationSeconds: 2400),
          0);
    });

    test('phimapi tua đúng chỗ đang xem dở', () {
      expect(
          resumePosition(
              provider: kSrcPhimApi, positionSeconds: 600, durationSeconds: 2400),
          600);
    });

    test('gần hết tập thì phát lại từ đầu, không nhảy vào đoạn cuối', () {
      expect(
          resumePosition(
              provider: kSrcPhimApi, positionSeconds: 2380, durationSeconds: 2400),
          0);
    });

    test('mới xem vài giây thì khỏi tua', () {
      expect(
          resumePosition(
              provider: kSrcPhimApi, positionSeconds: 3, durationSeconds: 2400),
          0);
    });

    test('chưa biết thời lượng vẫn tua được', () {
      expect(
          resumePosition(
              provider: kSrcPhimApi, positionSeconds: 600, durationSeconds: 0),
          600);
    });
  });
}
