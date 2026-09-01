import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/data/aggregate_source.dart';
import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/models/movie.dart';
import 'package:app_xem_phim/models/movie_detail.dart';
import 'package:app_xem_phim/models/paginated.dart';

Movie _m(String slug, {String name = '', String origin = '', String year = '2026'}) =>
    Movie(
      name: name.isEmpty ? slug : name,
      slug: slug,
      originalName: origin,
      thumbUrl: '', posterUrl: '', description: '',
      quality: '', language: '', currentEpisode: '',
      totalEpisodes: 0, year: year,
    );

/// Nguồn giả: mỗi trang trả về danh sách đã dựng sẵn; hết trang thì ném lỗi.
class _FakeSource implements MovieSource {
  @override
  final String id;
  final Map<int, List<Movie>> pages;
  final int totalPage;
  final List<String> calls = [];

  _FakeSource(this.id, this.pages, {this.totalPage = 1});

  Future<Paginated<Movie>> _page(String what, int p) async {
    calls.add('$what:$p');
    final items = pages[p];
    if (items == null) throw ApiException('hết trang');
    return Paginated(items: items, currentPage: p, totalPage: totalPage);
  }

  @override
  Future<Paginated<Movie>> latest({int page = 1}) => _page('latest', page);
  @override
  Future<Paginated<Movie>> listByType(String t, {int page = 1}) => _page('type', page);
  @override
  Future<Paginated<Movie>> byGenre(String s, {int page = 1}) => _page('genre', page);
  @override
  Future<Paginated<Movie>> byCountry(String s, {int page = 1}) => _page('country', page);
  @override
  Future<Paginated<Movie>> byYear(String y, {int page = 1}) => _page('year', page);
  @override
  Future<Paginated<Movie>> browse(BrowseFilter f, {int page = 1}) => _page('browse', page);
  @override
  Future<List<Movie>> search(String k) async => pages[1] ?? [];
  @override
  Future<MovieDetail> detail(String slug) async {
    calls.add('detail:$slug');
    return MovieDetail(
      base: _m(slug), genres: [], countries: [], servers: [],
    );
  }
}

void main() {
  test('gộp: nguồn đầu trước, nguồn sau bù phim còn thiếu', () async {
    final a = _FakeSource(kSrcNguonc, {
      1: [_m('x'), _m('y')]
    }, totalPage: 1);
    final b = _FakeSource(kSrcPhimApi, {
      1: [_m('pa:z')]
    }, totalPage: 1);

    final res = await AggregateSource([a, b]).latest();
    expect(res.items.map((m) => m.slug), ['x', 'y', 'pa:z']);
  });

  test('lọc trùng theo tên gốc + năm dù slug hai bên khác nhau', () async {
    final a = _FakeSource(kSrcNguonc, {
      1: [_m('sep-chinh-la-than-tuong', name: 'Sếp Chính Là Thần Tượng', origin: 'My Bias, My Boss')]
    });
    final b = _FakeSource(kSrcPhimApi, {
      1: [
        _m('pa:sep-chinh-la-than-tuong-bias-toi-sep-cua-toi',
            name: 'Sếp Chính Là Thần Tượng (Bias tôi, sếp của tôi)',
            origin: 'My Bias, My Boss'),
        _m('pa:phim-rieng', origin: 'Only Here'),
      ]
    });

    final res = await AggregateSource([a, b]).latest();
    // Phim trùng chỉ còn bản của nguonc (nguồn ưu tiên).
    expect(res.items.map((m) => m.slug),
        ['sep-chinh-la-than-tuong', 'pa:phim-rieng']);
  });

  test('endpoint không trả năm (tìm kiếm nguonc) vẫn lọc được trùng', () async {
    final a = _FakeSource(kSrcNguonc, {
      1: [_m('sep-chinh-la-than-tuong', origin: 'My Bias, My Boss', year: '')]
    });
    final b = _FakeSource(kSrcPhimApi, {
      1: [_m('pa:sep-chinh-la-than-tuong-bias-toi-sep-cua-toi',
          origin: 'My Bias, My Boss', year: '2026')]
    });
    final res = await AggregateSource([a, b]).search('sep chinh la than tuong');
    expect(res.map((m) => m.slug), ['sep-chinh-la-than-tuong']);
  });

  test('cùng tên gốc nhưng KHÁC năm thì không coi là trùng', () async {
    final a = _FakeSource(kSrcNguonc, {1: [_m('a1', origin: 'Same Show', year: '2025')]});
    final b = _FakeSource(kSrcPhimApi, {1: [_m('pa:a2', origin: 'Same Show', year: '2026')]});
    final res = await AggregateSource([a, b]).latest();
    expect(res.items.length, 2);
  });

  test('nguồn hết trang thì bỏ qua, nguồn còn phim vẫn chạy tiếp', () async {
    final a = _FakeSource(kSrcNguonc, {1: [_m('x')]}, totalPage: 1);
    final b = _FakeSource(kSrcPhimApi, {
      1: [_m('pa:1')],
      2: [_m('pa:2')],
    }, totalPage: 5);

    final agg = AggregateSource([a, b]);
    final p1 = await agg.latest(page: 1);
    expect(p1.totalPage, 5); // tổng trang lấy theo nguồn nhiều nhất
    expect(p1.items.length, 2);

    final p2 = await agg.latest(page: 2);
    expect(p2.items.map((m) => m.slug), ['pa:2']);
    // Nguồn đã hết trang thì KHÔNG gọi lại nữa.
    expect(a.calls, ['latest:1']);
  });

  test('mọi nguồn lỗi thì ném ApiException chứ không im lặng trả rỗng', () async {
    final a = _FakeSource(kSrcNguonc, {});
    final b = _FakeSource(kSrcPhimApi, {});
    expect(() => AggregateSource([a, b]).latest(), throwsA(isA<ApiException>()));
  });

  test('detail() đi đúng nguồn theo tiền tố slug', () async {
    final a = _FakeSource(kSrcNguonc, {});
    final b = _FakeSource(kSrcPhimApi, {});
    final agg = AggregateSource([a, b]);
    await agg.detail('phim-nguonc');
    await agg.detail('pa:phim-moi');
    expect(a.calls, ['detail:phim-nguonc']);
    expect(b.calls, ['detail:pa:phim-moi']);
  });

  test('tắt một nguồn: danh mục bỏ nguồn đó nhưng phim đã lưu vẫn mở được', () async {
    final a = _FakeSource(kSrcNguonc, {1: [_m('x')]});
    final b = _FakeSource(kSrcPhimApi, {1: [_m('pa:z')]});
    final agg = AggregateSource([a], detailSources: [a, b]);

    final res = await agg.latest();
    expect(res.items.map((m) => m.slug), ['x']);

    await agg.detail('pa:z'); // phim cũ trong Yêu thích vẫn mở được
    expect(b.calls, ['detail:pa:z']);
  });
}
