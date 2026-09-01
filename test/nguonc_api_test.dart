import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_xem_phim/data/nguonc_api.dart';
import 'package:app_xem_phim/data/movie_source.dart';

void main() {
  test('latest() gọi đúng URL + gửi User-Agent, parse paginate & items', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'paginate': {'current_page': 1, 'total_page': 5},
          'items': [
            {'name': 'A', 'slug': 'a', 'total_episodes': 1},
            {'name': 'B', 'slug': 'b', 'total_episodes': 2},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = NguoncApi(client: client);
    final res = await api.latest(page: 1);

    expect(captured.url.toString(),
        'https://phim.nguonc.com/api/films/phim-moi-cap-nhat?page=1');
    expect(captured.headers['User-Agent'], contains('Mozilla/5.0'));
    expect(res.totalPage, 5);
    expect(res.items.length, 2);
    expect(res.items.first.name, 'A');
  });

  test('detail() parse movie', () async {
    final client = MockClient((req) async => http.Response(
          jsonEncode({
            'status': 'success',
            'movie': {
              'name': 'Phim A', 'slug': 'phim-a', 'total_episodes': 1,
              'category': {}, 'episodes': []
            }
          }),
          200));
    final api = NguoncApi(client: client);
    final d = await api.detail('phim-a');
    expect(d.name, 'Phim A');
  });

  test('lỗi HTTP ném ApiException', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    final api = NguoncApi(client: client);
    expect(() => api.latest(), throwsA(isA<ApiException>()));
  });

  test('browse() ghép 2 chiều cấu trúc -> nguonc NÉM lỗi (để aggregate bỏ qua)', () async {
    final client = MockClient((req) async => http.Response('{}', 200));
    final api = NguoncApi(client: client);
    expect(
      () => api.browse(const BrowseFilter(genre: 'hanh-dong', country: 'han-quoc')),
      throwsA(isA<ApiException>()),
    );
  });

  test('browse() một chiều + năm: gọi endpoint thể loại rồi lọc năm phía app', () async {
    late String path;
    final client = MockClient((req) async {
      path = req.url.path;
      return http.Response(
        jsonEncode({
          'paginate': {'current_page': 1, 'total_page': 2},
          'items': [
            {'name': 'A', 'slug': 'a', 'year': '2024', 'total_episodes': 1},
            {'name': 'B', 'slug': 'b', 'year': '2023', 'total_episodes': 1},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = NguoncApi(client: client);
    final r = await api.browse(const BrowseFilter(genre: 'hanh-dong', year: '2024'));
    expect(path, '/api/films/the-loai/hanh-dong'); // một chiều đi máy chủ
    expect(r.items.map((m) => m.slug), ['a']);      // lọc năm 2024 phía app
  });
}
