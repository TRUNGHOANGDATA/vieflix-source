import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_xem_phim/data/nguonc_api.dart';

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
}
