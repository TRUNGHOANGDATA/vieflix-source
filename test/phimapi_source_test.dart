import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/data/phimapi_source.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('listByType() parse dạng /v1/api + nối CDN vào ảnh tương đối', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return _json({
        'status': 'True',
        'data': {
          'APP_DOMAIN_CDN_IMAGE': 'https://phimimg.com',
          'items': [
            {
              'name': 'Phim A',
              'slug': 'phim-a',
              'origin_name': 'Movie A',
              'thumb_url': 'uploads/a-thumb.webp',
              'poster_url': 'https://cdn.khac/a.jpg',
              'quality': 'FHD',
              'lang': 'Vietsub + Thuyết Minh',
              'episode_current': 'Tập 7',
              'year': 2026,
              'category': [
                {'name': 'Hành Động', 'slug': 'hanh-dong'}
              ],
            }
          ],
          'params': {
            'pagination': {'currentPage': 2, 'totalPages': 4467}
          },
        },
      });
    });

    final res = await PhimApiSource(client: client).listByType('phim-bo', page: 2);

    expect(captured.url.toString(),
        contains('https://phimapi.com/v1/api/danh-sach/phim-bo?page=2'));
    expect(captured.headers['User-Agent'], contains('Mozilla/5.0'));
    expect(res.currentPage, 2);
    expect(res.totalPage, 4467);

    final m = res.items.single;
    // slug mang tiền tố để không lẫn với phim của nguonc
    expect(m.slug, '${kPhimApiPrefix}phim-a');
    expect(sourceOfSlug(m.slug), kSrcPhimApi);
    expect(m.thumbUrl, 'https://phimimg.com/uploads/a-thumb.webp');
    expect(m.posterUrl, 'https://cdn.khac/a.jpg'); // đã tuyệt đối thì giữ nguyên
    expect(m.year, '2026');
    expect(m.hasThuyetMinh, isTrue);
    expect(m.genres, ['Hành Động']);
  });

  test('latest() dùng endpoint v3 (items ở ngoài cùng)', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return _json({
        'status': true,
        'items': [
          {'name': 'B', 'slug': 'b', 'poster_url': 'https://x/b.jpg', 'year': 2020}
        ],
        'pagination': {'currentPage': 1, 'totalPages': 12},
      });
    });

    final res = await PhimApiSource(client: client).latest();
    expect(captured.url.path, '/danh-sach/phim-moi-cap-nhat-v3');
    expect(res.totalPage, 12);
    expect(res.items.single.slug, '${kPhimApiPrefix}b');
  });

  test('byGenre() đổi slug khác tên và đưa hoạt hình về danh sách', () async {
    final urls = <String>[];
    final client = MockClient((req) async {
      urls.add(req.url.path);
      return _json({'data': {'items': []}});
    });
    final api = PhimApiSource(client: client);
    await api.byGenre('hai');       // tên trong danh mục app
    await api.byGenre('phim-hai');  // slug nguonc dùng
    await api.byGenre('khoa-hoc-vien-tuong'); // nguonc gọi vậy, phimapi gọi khác
    await api.byGenre('hanh-dong'); // hai bên giống nhau
    await api.byGenre('hoat-hinh'); // bên phimapi là DANH SÁCH, không phải thể loại
    expect(urls, [
      '/v1/api/the-loai/hai-huoc',
      '/v1/api/the-loai/hai-huoc',
      '/v1/api/the-loai/vien-tuong',
      '/v1/api/the-loai/hanh-dong',
      '/v1/api/danh-sach/hoat-hinh',
    ]);
  });

  test('detail() bỏ tiền tố slug, lấy cả m3u8 lẫn embed, bỏ thẻ HTML', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return _json({
        'status': 'True',
        'movie': {
          'name': 'Phim A',
          'slug': 'phim-a',
          'origin_name': 'Movie A',
          'content': '<p>Nội dung <b>hay</b>.</p><p>Dòng hai &amp; hết.</p>',
          'year': 2026,
          'episode_total': '12',
          'lang': 'Vietsub',
          'director': ['Đạo Diễn A'],
          'actor': ['Diễn Viên 1', 'Diễn Viên 2'],
          'category': [
            {'name': 'Hành Động', 'slug': 'hanh-dong'}
          ],
          'country': [
            {'name': 'Hàn Quốc', 'slug': 'han-quoc'}
          ],
        },
        'episodes': [
          {
            'server_name': 'Vietsub',
            'server_data': [
              {
                'name': 'Tập 01',
                'slug': 'tap-01',
                'link_embed': 'https://player.phimapi.com/player/?url=x.m3u8',
                'link_m3u8': 'https://v7.kkphimplayer7.com/x/index.m3u8',
              }
            ],
          },
          {'server_name': 'Thuyết Minh', 'server_data': []},
        ],
      });
    });

    final d = await PhimApiSource(client: client).detail('${kPhimApiPrefix}phim-a');

    expect(captured.url.path, '/phim/phim-a'); // tiền tố đã bỏ khi gọi API
    expect(d.name, 'Phim A');
    expect(d.year, '2026');
    expect(d.base.totalEpisodes, 12);
    expect(d.description, 'Nội dung hay.\n\nDòng hai & hết.');
    expect(d.director, 'Đạo Diễn A');
    expect(d.casts, 'Diễn Viên 1, Diễn Viên 2');
    expect(d.genres.single.slug, 'hanh-dong');
    expect(d.countries.single.slug, 'han-quoc');
    expect(d.servers.map((s) => s.serverName), ['Vietsub', 'Thuyết Minh']);

    final ep = d.servers.first.items.single;
    expect(ep.embed, contains('player.phimapi.com'));
    expect(ep.m3u8, 'https://v7.kkphimplayer7.com/x/index.m3u8');
  });

  test('lỗi HTTP ném ApiException', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    expect(() => PhimApiSource(client: client).latest(),
        throwsA(isA<ApiException>()));
  });
}
