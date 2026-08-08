# App Xem Phim (Windows) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây app xem phim desktop Windows giao diện kiểu Netflix (tiếng Việt, nền đen/đỏ), đọc dữ liệu từ API nguonc, phát video bằng WebView "hộp kín" chặn sạch quảng cáo. Đây là Giai đoạn 1; Giai đoạn 2 (Android TV) tái sử dụng lõi này.

**Architecture:** Flutter app phân lớp: UI (widgets) → State (Riverpod) → Data (`NguoncApi` gọi HTTP + `LocalStore` lưu cục bộ) → Player (`flutter_inappwebview` + `AdBlocker`). Mỗi lớp ranh giới rõ, test độc lập được.

**Tech Stack:** Flutter (stable), Dart. Packages: `http`, `flutter_riverpod`, `shared_preferences`, `flutter_inappwebview` (^6.x), `cached_network_image`. Build target: Windows desktop (WebView2 có sẵn trên Windows 11).

## Global Constraints

- **Ngôn ngữ UI:** tiếng Việt. **Theme:** nền tối đen (`#141414`) + điểm nhấn đỏ (`#E50914`), chữ trắng.
- **API base:** `https://phim.nguonc.com/api`. **Mọi** request HTTP phải gửi header `User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36` để tránh 403.
- **Không** tự giải mã stream. Video phát qua `flutter_inappwebview` nạp URL `embed` của phim.
- **Chặn quảng cáo bắt buộc:** ContentBlocker (chặn domain QC) + user script (chặn `window.open`, ẩn overlay, vô hiệu `devtoolsDetector` reload).
- **Lưu cục bộ:** `shared_preferences`, key JSON. Không server, không đăng nhập.
- **State management:** Riverpod (`flutter_riverpod`).
- **Platform Giai đoạn 1:** chỉ Windows. Không macOS/Linux/mobile.
- Mọi ảnh dùng `cached_network_image` để mượt.
- Commit thường xuyên sau mỗi task.

---

## File Structure

```
lib/
  main.dart                     # Khởi động app, ProviderScope, MaterialApp, theme
  theme/app_theme.dart          # Màu, ThemeData đen/đỏ
  models/
    movie.dart                  # Movie (item danh sách)
    movie_detail.dart           # MovieDetail + CategoryGroup
    episode.dart                # ServerGroup + Episode
    paginated.dart              # Paginated<T> (items + total_page)
  data/
    nguonc_api.dart             # Client gọi API, trả models
    local_store.dart            # Yêu thích + Xem tiếp (shared_preferences)
  player/
    ad_blocker.dart             # Blocklist + ContentBlocker rules + user scripts
    player_screen.dart          # WebView hộp kín
  state/
    providers.dart              # Riverpod providers (api, store, home rows...)
  widgets/
    movie_card.dart             # Poster card (hover/focus phóng to)
    movie_row.dart              # Hàng cuộn ngang
    hero_banner.dart            # Banner lớn trang chủ
    async_view.dart             # Bọc loading/error/retry dùng chung
  screens/
    home_screen.dart
    detail_screen.dart
    browse_screen.dart          # Duyệt + lọc nâng cao
    search_screen.dart
    my_list_screen.dart
    shell.dart                  # Khung điều hướng (sidebar/tab)
  constants/catalog.dart        # Slug thể loại/quốc gia/năm cố định (tiếng Việt)
test/
  models_test.dart
  nguonc_api_test.dart
  local_store_test.dart
  ad_blocker_test.dart
```

---

## Task 0: Môi trường & khởi tạo dự án Flutter

**Files:**
- Create: toàn bộ scaffold Flutter (`pubspec.yaml`, `lib/main.dart`, thư mục `windows/`).

**Interfaces:**
- Produces: một app Flutter Windows chạy được (cửa sổ trắng), lệnh `flutter run -d windows` hoạt động.

- [ ] **Step 1: Cài công cụ (chạy trên máy người dùng)**

Kiểm tra Flutter đã có chưa:
```bash
flutter --version
```
Nếu **chưa có Flutter**: tải Flutter SDK stable cho Windows từ trang chính thức, giải nén vào `C:\src\flutter`, thêm `C:\src\flutter\bin` vào PATH. Cần **Visual Studio 2022** với workload **"Desktop development with C++"** (bắt buộc để build app Windows). Git for Windows cũng cần có.

- [ ] **Step 2: Kiểm tra doctor**

Run: `flutter doctor`
Expected: mục **"Visual Studio - develop Windows apps"** có dấu ✓. (Bỏ qua Android/Chrome ở giai đoạn này.)

- [ ] **Step 3: Bật hỗ trợ desktop & tạo dự án**

```bash
flutter config --enable-windows-desktop
cd "H:/Tao App Xem Phim"
flutter create --project-name app_xem_phim --platforms=windows .
```

- [ ] **Step 4: Thêm dependencies**

Sửa `pubspec.yaml` mục `dependencies:` thành:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  flutter_riverpod: ^2.5.1
  shared_preferences: ^2.2.3
  flutter_inappwebview: ^6.1.5
  cached_network_image: ^3.3.1
```
Rồi chạy:
```bash
flutter pub get
```

- [ ] **Step 5: Chạy thử app trống**

Run: `flutter run -d windows`
Expected: mở ra cửa sổ app đếm số (counter demo) — xác nhận toolchain build Windows OK.

- [ ] **Step 6: Commit**

```bash
git init
git add -A
git commit -m "chore: khởi tạo dự án Flutter Windows + dependencies"
```

---

## Task 1: Models (Movie, MovieDetail, Episode, Paginated)

**Files:**
- Create: `lib/models/movie.dart`, `lib/models/movie_detail.dart`, `lib/models/episode.dart`, `lib/models/paginated.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Produces:
  - `Movie.fromJson(Map<String,dynamic>) -> Movie` với fields: `String name, slug, originalName, thumbUrl, posterUrl, description, quality, language, currentEpisode; int totalEpisodes`.
  - `class Paginated<T> { final List<T> items; final int currentPage; final int totalPage; }`
  - `MovieDetail.fromJson(Map<String,dynamic>)` fields: tất cả của Movie + `List<CategoryItem> genres, countries; String? year, director, casts; List<ServerGroup> servers`.
  - `class CategoryItem { final String name, slug; }`
  - `class ServerGroup { final String serverName; final List<Episode> items; }`
  - `class Episode { final String name, slug, embed; }`

- [ ] **Step 1: Viết test (fail trước)**

`test/models_test.dart`:
```dart
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
}
```

- [ ] **Step 2: Chạy test để thấy FAIL**

Run: `flutter test test/models_test.dart`
Expected: FAIL (chưa có class).

- [ ] **Step 3: Viết models**

`lib/models/movie.dart`:
```dart
class Movie {
  final String name, slug, originalName, thumbUrl, posterUrl, description;
  final String quality, language, currentEpisode;
  final int totalEpisodes;

  Movie({
    required this.name, required this.slug, required this.originalName,
    required this.thumbUrl, required this.posterUrl, required this.description,
    required this.quality, required this.language, required this.currentEpisode,
    required this.totalEpisodes,
  });

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
      );
}
```

`lib/models/paginated.dart`:
```dart
class Paginated<T> {
  final List<T> items;
  final int currentPage, totalPage;
  Paginated({required this.items, required this.currentPage, required this.totalPage});
}
```

`lib/models/episode.dart`:
```dart
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
```

`lib/models/movie_detail.dart`:
```dart
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
```

- [ ] **Step 4: Chạy test để thấy PASS**

Run: `flutter test test/models_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/models test/models_test.dart
git commit -m "feat: models Movie/MovieDetail/Episode + parse category"
```

---

## Task 2: NguoncApi client

**Files:**
- Create: `lib/data/nguonc_api.dart`
- Test: `test/nguonc_api_test.dart`

**Interfaces:**
- Consumes: models Task 1.
- Produces class `NguoncApi`:
  - `NguoncApi({http.Client? client})`
  - `Future<Paginated<Movie>> latest({int page = 1})`
  - `Future<Paginated<Movie>> listByType(String type, {int page = 1})` — type ∈ `phim-bo|phim-le|hoat-hinh|tv-shows`
  - `Future<Paginated<Movie>> byGenre(String slug, {int page = 1})`
  - `Future<Paginated<Movie>> byCountry(String slug, {int page = 1})`
  - `Future<Paginated<Movie>> byYear(String year, {int page = 1})`
  - `Future<List<Movie>> search(String keyword)`
  - `Future<MovieDetail> detail(String slug)`
  - throws `ApiException` khi lỗi.

- [ ] **Step 1: Viết test (fail trước)**

`test/nguonc_api_test.dart`:
```dart
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
```

- [ ] **Step 2: Chạy test để thấy FAIL**

Run: `flutter test test/nguonc_api_test.dart`
Expected: FAIL (chưa có `NguoncApi`).

- [ ] **Step 3: Viết client**

`lib/data/nguonc_api.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/paginated.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class NguoncApi {
  final http.Client _client;
  static const _base = 'https://phim.nguonc.com/api';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  NguoncApi({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _getJson(String path) async {
    late http.Response r;
    try {
      r = await _client.get(Uri.parse('$_base$path'),
          headers: {'User-Agent': _ua, 'Accept': 'application/json'});
    } catch (e) {
      throw ApiException('Lỗi mạng: $e');
    }
    if (r.statusCode != 200) {
      throw ApiException('Máy chủ trả về ${r.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException('Dữ liệu không hợp lệ');
    }
  }

  Paginated<Movie> _parseList(Map<String, dynamic> j) {
    final p = (j['paginate'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = ((j['items'] as List?) ?? [])
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
    return Paginated(
      items: items,
      currentPage: (p['current_page'] is int) ? p['current_page'] : 1,
      totalPage: (p['total_page'] is int) ? p['total_page'] : 1,
    );
  }

  Future<Paginated<Movie>> latest({int page = 1}) async =>
      _parseList(await _getJson('/films/phim-moi-cap-nhat?page=$page'));

  Future<Paginated<Movie>> listByType(String type, {int page = 1}) async =>
      _parseList(await _getJson('/films/danh-sach/$type?page=$page'));

  Future<Paginated<Movie>> byGenre(String slug, {int page = 1}) async =>
      _parseList(await _getJson('/films/the-loai/$slug?page=$page'));

  Future<Paginated<Movie>> byCountry(String slug, {int page = 1}) async =>
      _parseList(await _getJson('/films/quoc-gia/$slug?page=$page'));

  Future<Paginated<Movie>> byYear(String year, {int page = 1}) async =>
      _parseList(await _getJson('/films/nam-phat-hanh/$year?page=$page'));

  Future<List<Movie>> search(String keyword) async {
    final j = await _getJson('/films/search?keyword=${Uri.encodeQueryComponent(keyword)}');
    return _parseList(j).items;
  }

  Future<MovieDetail> detail(String slug) async {
    final j = await _getJson('/film/$slug');
    final movie = (j['movie'] as Map?)?.cast<String, dynamic>();
    if (movie == null) throw ApiException('Không tìm thấy phim');
    return MovieDetail.fromJson(movie);
  }
}
```

- [ ] **Step 4: Chạy test để thấy PASS**

Run: `flutter test test/nguonc_api_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/data/nguonc_api.dart test/nguonc_api_test.dart
git commit -m "feat: NguoncApi client (list/detail/search) + User-Agent"
```

---

## Task 3: LocalStore (Yêu thích + Xem tiếp)

**Files:**
- Create: `lib/data/local_store.dart`
- Test: `test/local_store_test.dart`

**Interfaces:**
- Produces class `LocalStore`:
  - `Future<void> init()` (load từ SharedPreferences)
  - `List<Movie> get favorites`
  - `bool isFavorite(String slug)`
  - `Future<void> toggleFavorite(Movie m)`
  - `Future<void> saveProgress({required String slug, required String server, required String episodeSlug, required String episodeName})`
  - `WatchProgress? progressFor(String slug)`
  - `List<WatchProgress> get continueWatching` (mới nhất trước)
  - `class WatchProgress { final String slug, server, episodeSlug, episodeName; final int updatedAt; }`

- [ ] **Step 1: Viết test (fail trước)**

`test/local_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_xem_phim/data/local_store.dart';
import 'package:app_xem_phim/models/movie.dart';

Movie _mv(String slug) => Movie.fromJson({'name': slug, 'slug': slug, 'total_episodes': 1});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggleFavorite thêm rồi xóa', () async {
    final s = LocalStore();
    await s.init();
    expect(s.isFavorite('a'), false);
    await s.toggleFavorite(_mv('a'));
    expect(s.isFavorite('a'), true);
    expect(s.favorites.length, 1);
    await s.toggleFavorite(_mv('a'));
    expect(s.isFavorite('a'), false);
  });

  test('favorites bền qua lần init mới', () async {
    final s1 = LocalStore();
    await s1.init();
    await s1.toggleFavorite(_mv('b'));
    final s2 = LocalStore();
    await s2.init();
    expect(s2.isFavorite('b'), true);
  });

  test('saveProgress lưu và đọc lại, continueWatching mới nhất trước', () async {
    final s = LocalStore();
    await s.init();
    await s.saveProgress(slug: 'x', server: 'Vietsub #1', episodeSlug: 'tap-3', episodeName: '3');
    await s.saveProgress(slug: 'y', server: 'Vietsub #1', episodeSlug: 'tap-1', episodeName: '1');
    expect(s.progressFor('x')!.episodeName, '3');
    expect(s.continueWatching.first.slug, 'y'); // lưu sau -> đứng trước
  });
}
```

- [ ] **Step 2: Chạy test để thấy FAIL**

Run: `flutter test test/local_store_test.dart`
Expected: FAIL.

- [ ] **Step 3: Viết LocalStore**

`lib/data/local_store.dart`:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class WatchProgress {
  final String slug, server, episodeSlug, episodeName;
  final int updatedAt;
  WatchProgress({
    required this.slug, required this.server, required this.episodeSlug,
    required this.episodeName, required this.updatedAt,
  });
  Map<String, dynamic> toJson() => {
        'slug': slug, 'server': server, 'episodeSlug': episodeSlug,
        'episodeName': episodeName, 'updatedAt': updatedAt,
      };
  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        slug: j['slug'], server: j['server'], episodeSlug: j['episodeSlug'],
        episodeName: j['episodeName'], updatedAt: j['updatedAt'],
      );
}

class LocalStore {
  static const _kFav = 'favorites_v1';
  static const _kProg = 'progress_v1';
  late SharedPreferences _p;
  final List<Movie> _favorites = [];
  final Map<String, WatchProgress> _progress = {};

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _favorites
      ..clear()
      ..addAll(((jsonDecode(_p.getString(_kFav) ?? '[]')) as List)
          .map((e) => Movie.fromJson(_favFromStored(e))));
    _progress.clear();
    final pm = (jsonDecode(_p.getString(_kProg) ?? '{}')) as Map<String, dynamic>;
    pm.forEach((k, v) => _progress[k] = WatchProgress.fromJson(v as Map<String, dynamic>));
  }

  // Chỉ lưu field cần cho card để không phụ thuộc dữ liệu đầy đủ
  Map<String, dynamic> _favToStored(Movie m) => {
        'name': m.name, 'slug': m.slug, 'poster_url': m.posterUrl,
        'thumb_url': m.thumbUrl, 'quality': m.quality,
        'current_episode': m.currentEpisode, 'total_episodes': m.totalEpisodes,
      };
  Map<String, dynamic> _favFromStored(dynamic e) => (e as Map).cast<String, dynamic>();

  List<Movie> get favorites => List.unmodifiable(_favorites);
  bool isFavorite(String slug) => _favorites.any((m) => m.slug == slug);

  Future<void> toggleFavorite(Movie m) async {
    if (isFavorite(m.slug)) {
      _favorites.removeWhere((x) => x.slug == m.slug);
    } else {
      _favorites.insert(0, m);
    }
    await _p.setString(_kFav, jsonEncode(_favorites.map(_favToStored).toList()));
  }

  Future<void> saveProgress({
    required String slug, required String server,
    required String episodeSlug, required String episodeName,
  }) async {
    _progress[slug] = WatchProgress(
      slug: slug, server: server, episodeSlug: episodeSlug,
      episodeName: episodeName, updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _p.setString(_kProg,
        jsonEncode(_progress.map((k, v) => MapEntry(k, v.toJson()))));
  }

  WatchProgress? progressFor(String slug) => _progress[slug];

  List<WatchProgress> get continueWatching {
    final list = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
```

- [ ] **Step 4: Chạy test để thấy PASS**

Run: `flutter test test/local_store_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/data/local_store.dart test/local_store_test.dart
git commit -m "feat: LocalStore yêu thích + xem tiếp (shared_preferences)"
```

---

## Task 4: AdBlocker (chặn quảng cáo)

**Files:**
- Create: `lib/player/ad_blocker.dart`
- Test: `test/ad_blocker_test.dart`

**Interfaces:**
- Produces:
  - `bool isAdUrl(String url)` — true nếu URL khớp blocklist QC/tracker.
  - `List<ContentBlocker> adContentBlockers()` — rules cho InAppWebView.
  - `const String kAntiAdUserScript` — JS chặn `window.open`, ẩn overlay, vô hiệu reload.

- [ ] **Step 1: Viết test (fail trước)**

`test/ad_blocker_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app_xem_phim/player/ad_blocker.dart';

void main() {
  test('chặn domain quảng cáo/tracker đã biết', () {
    expect(isAdUrl('https://whos.amung.us/widget/x.js'), true);
    expect(isAdUrl('https://waust.at/s.js'), true);
    expect(isAdUrl('https://a.propellerads.com/x'), true);
    expect(isAdUrl('https://www.google-analytics.com/analytics.js'), true);
  });

  test('KHÔNG chặn host cần cho phát video', () {
    expect(isAdUrl('https://embed14.streamc.xyz/embed.php?hash=abc'), false);
    expect(isAdUrl('https://ssl.p.jwpcdn.com/player/v/8.38.2/jwplayer.js'), false);
    expect(isAdUrl('https://phim.nguonc.com/api/film/x'), false);
  });

  test('adContentBlockers trả về rules không rỗng', () {
    expect(adContentBlockers().isNotEmpty, true);
  });
}
```

- [ ] **Step 2: Chạy test để thấy FAIL**

Run: `flutter test test/ad_blocker_test.dart`
Expected: FAIL.

- [ ] **Step 3: Viết AdBlocker**

`lib/player/ad_blocker.dart`:
```dart
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Danh sách mảnh chuỗi domain quảng cáo/tracker cần chặn.
/// Mở rộng khi phát hiện QC mới (chỉ sửa data, không sửa logic).
const List<String> kAdHosts = [
  'whos.amung.us', 'waust.at',            // widget đếm (kèm QC)
  'propellerads', 'popads', 'popcash', 'poptm', 'popunder',
  'adsterra', 'hilltopads', 'onclicka', 'clickadu', 'adnxs',
  'exoclick', 'juicyads', 'trafficjunky', 'mgid',
  'doubleclick.net', 'googlesyndication', 'google-analytics',
  'googletagmanager', 'g.doubleclick', 'histats', 'statcounter',
  'yandex.ru/metrika', 'facebook.net', 'connect.facebook',
];

bool isAdUrl(String url) {
  final u = url.toLowerCase();
  for (final h in kAdHosts) {
    if (u.contains(h)) return true;
  }
  return false;
}

/// ContentBlocker rules: chặn tải mọi resource khớp host QC.
List<ContentBlocker> adContentBlockers() {
  return kAdHosts
      .map((h) => ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: '.*${RegExp.escape(h)}.*',
            ),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ))
      .toList();
}

/// JS tiêm sớm: vô hiệu popup/popunder, chặn reload anti-devtools, ẩn overlay QC.
const String kAntiAdUserScript = r'''
(function () {
  try {
    // 1) Chặn mở tab/popup quảng cáo
    window.open = function () { return null; };
    // 2) Vô hiệu anti-devtools reload của trang embed
    try { Object.defineProperty(window, 'devtoolsDetector', {
      value: { launch: function(){}, addListener: function(){} },
      configurable: true
    }); } catch (e) {}
    var _reload = location.reload.bind(location);
    location.reload = function () {}; // chặn vòng lặp reload
    // 3) Ẩn overlay/banner QC + cho video full khung
    var css = document.createElement('style');
    css.innerHTML = [
      '#_wau, ._wau, .ad, .ads, .adsbox, [id^="ad_"], [class*="popup"],',
      '[class*="overlay-ad"], [class*="banner"], iframe[src*="ads"] { display:none !important; }',
      'html, body { overflow:hidden !important; background:#000 !important; }',
      'video, .jwplayer, #player { width:100vw !important; height:100vh !important; }'
    ].join('\n');
    (document.head || document.documentElement).appendChild(css);
    // 4) Xóa các phần tử QC xuất hiện sau
    setInterval(function () {
      document.querySelectorAll('a[target="_blank"]').forEach(function (a) {
        a.removeAttribute('target');
      });
    }, 1000);
  } catch (e) {}
})();
''';
```

- [ ] **Step 4: Chạy test để thấy PASS**

Run: `flutter test test/ad_blocker_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/player/ad_blocker.dart test/ad_blocker_test.dart
git commit -m "feat: AdBlocker blocklist + ContentBlocker + user script chặn popup/overlay"
```

---

## Task 5: Theme + Catalog + Providers + App shell chạy được

**Files:**
- Create: `lib/theme/app_theme.dart`, `lib/constants/catalog.dart`, `lib/state/providers.dart`, `lib/screens/shell.dart`, `lib/widgets/async_view.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `NguoncApi` (Task 2), `LocalStore` (Task 3).
- Produces:
  - `appTheme` (ThemeData đen/đỏ), màu `kBg=Color(0xFF141414)`, `kRed=Color(0xFFE50914)`.
  - `apiProvider` (Provider<NguoncApi>), `storeProvider` ( chứa LocalStore đã init).
  - `kGenres`, `kCountries`, `kYears`, `kTypes` (danh sách `CatalogEntry{label,slug}`).
  - `AppShell` — Scaffold có điều hướng trái (Trang chủ / Duyệt / Tìm kiếm / Yêu thích).
  - `AsyncView<T>` widget bọc `AsyncValue` → loading/lỗi+Thử lại/nội dung.

- [ ] **Step 1: Theme**

`lib/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';

const kBg = Color(0xFF141414);
const kSurface = Color(0xFF1F1F1F);
const kRed = Color(0xFFE50914);

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kRed, surface: kSurface, background: kBg,
  ),
  fontFamily: 'Segoe UI',
  useMaterial3: true,
);
```

- [ ] **Step 2: Catalog (danh mục cố định tiếng Việt)**

`lib/constants/catalog.dart`:
```dart
class CatalogEntry {
  final String label, slug;
  const CatalogEntry(this.label, this.slug);
}

const kTypes = [
  CatalogEntry('Phim Bộ', 'phim-bo'),
  CatalogEntry('Phim Lẻ', 'phim-le'),
  CatalogEntry('Hoạt Hình', 'hoat-hinh'),
  CatalogEntry('TV Shows', 'tv-shows'),
];

const kGenres = [
  CatalogEntry('Hành Động', 'hanh-dong'),
  CatalogEntry('Tình Cảm', 'tinh-cam'),
  CatalogEntry('Hài', 'hai'),
  CatalogEntry('Kinh Dị', 'kinh-di'),
  CatalogEntry('Tâm Lý', 'tam-ly'),
  CatalogEntry('Cổ Trang', 'co-trang'),
  CatalogEntry('Viễn Tưởng', 'vien-tuong'),
  CatalogEntry('Hình Sự', 'hinh-su'),
  CatalogEntry('Chiến Tranh', 'chien-tranh'),
  CatalogEntry('Hoạt Hình', 'hoat-hinh'),
];

const kCountries = [
  CatalogEntry('Hàn Quốc', 'han-quoc'),
  CatalogEntry('Trung Quốc', 'trung-quoc'),
  CatalogEntry('Nhật Bản', 'nhat-ban'),
  CatalogEntry('Âu Mỹ', 'au-my'),
  CatalogEntry('Thái Lan', 'thai-lan'),
  CatalogEntry('Việt Nam', 'viet-nam'),
  CatalogEntry('Ấn Độ', 'an-do'),
];

const kYears = ['2026','2025','2024','2023','2022','2021','2020','2019'];
```
> Ghi chú: slug thể loại/quốc gia đã kiểm chứng dạng không dấu gạch nối. Nếu endpoint trả rỗng cho slug nào, chỉnh lại tại đây (chỉ sửa data).

- [ ] **Step 3: Providers**

`lib/state/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/nguonc_api.dart';
import '../data/local_store.dart';

final apiProvider = Provider<NguoncApi>((ref) => NguoncApi());

/// storeProvider được override ở main sau khi init().
final storeProvider = Provider<LocalStore>((ref) => throw UnimplementedError());
```

- [ ] **Step 4: AsyncView dùng chung**

`lib/widgets/async_view.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator(color: kRed)),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          const Text('Đã xảy ra lỗi khi tải dữ liệu', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 5: App shell + main**

`lib/screens/shell.dart`:
```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _i = 0;
  final _pages = const [HomeScreen(), BrowseScreen(), SearchScreen(), MyListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          backgroundColor: Colors.black,
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          labelType: NavigationRailLabelType.all,
          selectedIconTheme: const IconThemeData(color: kRed),
          selectedLabelTextStyle: const TextStyle(color: kRed),
          leading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('PHIM', style: TextStyle(color: kRed, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Trang chủ')),
            NavigationRailDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: Text('Duyệt')),
            NavigationRailDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: Text('Tìm kiếm')),
            NavigationRailDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: Text('Yêu thích')),
          ],
        ),
        Expanded(child: _pages[_i]),
      ]),
    );
  }
}
```

`lib/main.dart` (thay toàn bộ):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/local_store.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LocalStore();
  await store.init();
  runApp(ProviderScope(
    overrides: [storeProvider.overrideWithValue(store)],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Xem Phim',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AppShell(),
    );
  }
}
```

- [ ] **Step 6: Tạo file rỗng tạm cho 4 screen để build được**

Tạo tạm mỗi file trả về `Center(child: Text('...'))` để app biên dịch:
`lib/screens/home_screen.dart`, `browse_screen.dart`, `search_screen.dart`, `my_list_screen.dart` — mỗi file:
```dart
import 'package:flutter/material.dart';
class HomeScreen extends StatelessWidget { // đổi tên class cho từng file
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext c) => const Center(child: Text('Sắp có', style: TextStyle(color: Colors.white)));
}
```
(Đặt đúng tên class: `HomeScreen`, `BrowseScreen`, `SearchScreen`, `MyListScreen`.)

- [ ] **Step 7: Chạy app**

Run: `flutter run -d windows`
Expected: App mở, có thanh điều hướng trái đen với chữ "PHIM" đỏ + 4 mục; bấm chuyển thấy chữ "Sắp có".

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: theme đen/đỏ + catalog + providers + app shell điều hướng"
```

---

## Task 6: Widget dùng lại — MovieCard + MovieRow

**Files:**
- Create: `lib/widgets/movie_card.dart`, `lib/widgets/movie_row.dart`

**Interfaces:**
- Consumes: `Movie`.
- Produces:
  - `MovieCard(Movie movie, VoidCallback onTap)` — poster bo góc, phóng to khi hover/focus, hiện tên + chất lượng.
  - `MovieRow(String title, List<Movie> movies, void Function(Movie) onTap)` — tiêu đề + ListView ngang.

- [ ] **Step 1: MovieCard**

`lib/widgets/movie_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';

class MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double width;
  const MovieCard({super.key, required this.movie, required this.onTap, this.width = 150});
  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _hover = false;
  void _set(bool v) => setState(() => _hover = v);

  @override
  Widget build(BuildContext context) {
    final img = widget.movie.thumbUrl.isNotEmpty ? widget.movie.thumbUrl : widget.movie.posterUrl;
    return FocusableActionDetector(
      onShowHoverHighlight: _set,
      onShowFocusHighlight: _set,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.width,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _hover ? kRed : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: CachedNetworkImage(
                    imageUrl: img, fit: BoxFit.cover,
                    placeholder: (c, _) => Container(color: kSurface),
                    errorWidget: (c, _, __) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.white24)),
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(4),
                  child: Text(widget.movie.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: MovieRow**

`lib/widgets/movie_row.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/movie.dart';
import 'movie_card.dart';

class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final void Function(Movie) onTap;
  const MovieRow({super.key, required this.title, required this.movies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: movies.length,
          itemBuilder: (c, i) => MovieCard(movie: movies[i], onTap: () => onTap(movies[i])),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 3: Kiểm tra biên dịch**

Run: `flutter analyze lib/widgets`
Expected: No issues (hoặc chỉ info).

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/movie_card.dart lib/widgets/movie_row.dart
git commit -m "feat: MovieCard (hover/focus) + MovieRow cuộn ngang"
```

---

## Task 7: Home screen (hero banner + nhiều hàng)

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Create: `lib/widgets/hero_banner.dart`
- Modify: `lib/state/providers.dart` (thêm providers cho các hàng)

**Interfaces:**
- Consumes: `apiProvider`, `MovieRow`, `MovieCard`, models.
- Produces: `HomeScreen` hiển thị banner + các hàng (Mới cập nhật, Phim bộ, Phim lẻ, Hoạt hình, TV Shows, 2 thể loại). Bấm card → mở `DetailScreen` (Task 8). Nút ▶ trên banner cũng mở Detail.

- [ ] **Step 1: Thêm providers cho các hàng**

Thêm vào `lib/state/providers.dart`:
```dart
import '../models/movie.dart';
import '../models/paginated.dart';

final latestProvider = FutureProvider<Paginated<Movie>>((ref) => ref.read(apiProvider).latest());
final typeRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, type) async => (await ref.read(apiProvider).listByType(type)).items);
final genreRowProvider = FutureProvider.family<List<Movie>, String>(
    (ref, slug) async => (await ref.read(apiProvider).byGenre(slug)).items);
```

- [ ] **Step 2: HeroBanner**

`lib/widgets/hero_banner.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';

class HeroBanner extends StatelessWidget {
  final Movie movie;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  const HeroBanner({super.key, required this.movie, required this.onPlay, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.thumbUrl,
          fit: BoxFit.cover,
          errorWidget: (c, _, __) => Container(color: kSurface),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [Colors.black, Colors.black54, Colors.transparent],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.center,
              colors: [kBg, Colors.transparent],
            ),
          ),
        ),
        Positioned(
          left: 40, bottom: 60, right: 300,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(movie.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kRed, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                onPressed: onPlay, icon: const Icon(Icons.play_arrow), label: const Text('Xem ngay'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                onPressed: onInfo, icon: const Icon(Icons.info_outline), label: const Text('Chi tiết'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 3: HomeScreen**

`lib/screens/home_screen.dart` (thay toàn bộ):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../widgets/movie_row.dart';
import '../widgets/hero_banner.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _open(BuildContext c, Movie m) => Navigator.of(c).push(
      MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestProvider);
    return AsyncView(
      value: latest,
      onRetry: () => ref.invalidate(latestProvider),
      builder: (page) {
        final movies = page.items;
        final hero = movies.isNotEmpty ? movies.first : null;
        return ListView(children: [
          if (hero != null)
            HeroBanner(movie: hero, onPlay: () => _open(context, hero), onInfo: () => _open(context, hero)),
          MovieRow(title: 'Mới cập nhật', movies: movies, onTap: (m) => _open(context, m)),
          _typeRow(ref, context, 'Phim Bộ', 'phim-bo'),
          _typeRow(ref, context, 'Phim Lẻ', 'phim-le'),
          _typeRow(ref, context, 'Hoạt Hình', 'hoat-hinh'),
          _typeRow(ref, context, 'TV Shows', 'tv-shows'),
          _genreRow(ref, context, 'Hành Động', 'hanh-dong'),
          _genreRow(ref, context, 'Tình Cảm', 'tinh-cam'),
          const SizedBox(height: 40),
        ]);
      },
    );
  }

  Widget _typeRow(WidgetRef ref, BuildContext c, String title, String type) {
    final v = ref.watch(typeRowProvider(type));
    return v.maybeWhen(
      data: (list) => MovieRow(title: title, movies: list, onTap: (m) => _open(c, m)),
      orElse: () => const SizedBox(height: 8),
    );
  }

  Widget _genreRow(WidgetRef ref, BuildContext c, String title, String slug) {
    final v = ref.watch(genreRowProvider(slug));
    return v.maybeWhen(
      data: (list) => MovieRow(title: title, movies: list, onTap: (m) => _open(c, m)),
      orElse: () => const SizedBox(height: 8),
    );
  }
}
```

- [ ] **Step 4: Chạy & kiểm tra bằng mắt**

Run: `flutter run -d windows`
Expected: Trang chủ có banner lớn phim đầu tiên + các hàng phim cuộn ngang; hover phóng to; bấm card mở màn Detail (tạm thời "Sắp có" nếu Task 8 chưa làm — làm Task 8 ngay sau).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: Home screen hero banner + các hàng phim"
```

---

## Task 8: Detail screen

**Files:**
- Modify: `lib/screens/detail_screen.dart` (tạo mới thay file tạm)
- Modify: `lib/state/providers.dart` (thêm `detailProvider`)

**Interfaces:**
- Consumes: `apiProvider`, `storeProvider`, `MovieDetail`, `MovieRow`.
- Produces: `DetailScreen({required String slug, required String title})` — hiển thị thông tin, nút Yêu thích (toggle qua `storeProvider`), chọn server + danh sách tập → mở `PlayerScreen` (Task 9), hàng "Phim tương tự" theo genre đầu.

- [ ] **Step 1: detailProvider**

Thêm vào `lib/state/providers.dart`:
```dart
import '../models/movie_detail.dart';

final detailProvider = FutureProvider.family<MovieDetail, String>(
    (ref, slug) => ref.read(apiProvider).detail(slug));
```

- [ ] **Step 2: DetailScreen**

`lib/screens/detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/movie_detail.dart';
import '../models/episode.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/async_view.dart';
import '../widgets/movie_row.dart';
import '../player/player_screen.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final String slug, title;
  const DetailScreen({super.key, required this.slug, required this.title});
  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  int _server = 0;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title)),
      body: AsyncView<MovieDetail>(
        value: detail,
        onRetry: () => ref.invalidate(detailProvider(widget.slug)),
        builder: (d) => _content(d),
      ),
    );
  }

  Widget _content(MovieDetail d) {
    final store = ref.watch(storeProvider);
    final fav = store.isFavorite(d.slug);
    final servers = d.servers;
    final hasServer = servers.isNotEmpty;
    return ListView(children: [
      SizedBox(
        height: 320,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: d.posterUrl, fit: BoxFit.cover, errorWidget: (c, _, __) => Container(color: kSurface)),
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [kBg, Colors.transparent]))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (d.year != null) _chip(d.year!),
            _chip(d.base.quality),
            for (final g in d.genres.take(3)) _chip(g.name),
            for (final c in d.countries.take(1)) _chip(c.name),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: hasServer ? () => _play(d, servers[_server], servers[_server].items.first) : null,
              icon: const Icon(Icons.play_arrow), label: const Text('Xem ngay'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async { await store.toggleFavorite(d.base); setState(() {}); },
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : Colors.white),
              label: Text(fav ? 'Đã thích' : 'Yêu thích', style: const TextStyle(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 16),
          if (d.director != null) Text('Đạo diễn: ${d.director}', style: const TextStyle(color: Colors.white70)),
          if (d.casts != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Diễn viên: ${d.casts}', style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 12),
          Text(d.description, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 20),
          if (hasServer) ...[
            Wrap(spacing: 8, children: [
              for (int i = 0; i < servers.length; i++)
                ChoiceChip(
                  label: Text(servers[i].serverName),
                  selected: _server == i,
                  selectedColor: kRed,
                  onSelected: (_) => setState(() => _server = i),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ep in servers[_server].items)
                ActionChip(
                  backgroundColor: kSurface,
                  label: Text('Tập ${ep.name}', style: const TextStyle(color: Colors.white)),
                  onPressed: () => _play(d, servers[_server], ep),
                ),
            ]),
          ] else
            const Text('Phim chưa có nguồn phát.', style: TextStyle(color: Colors.white54)),
        ]),
      ),
      if (d.genres.isNotEmpty) _similar(d),
      const SizedBox(height: 30),
    ]);
  }

  Widget _chip(String s) => Chip(label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: kSurface, visualDensity: VisualDensity.compact);

  Widget _similar(MovieDetail d) {
    final v = ref.watch(genreRowProvider(d.genres.first.slug));
    return v.maybeWhen(
      data: (list) => MovieRow(
        title: 'Phim tương tự',
        movies: list.where((m) => m.slug != d.slug).toList(),
        onTap: (m) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _play(MovieDetail d, ServerGroup s, Episode ep) {
    ref.read(storeProvider).saveProgress(slug: d.slug, server: s.serverName, episodeSlug: ep.slug, episodeName: ep.name);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: '${d.name} - Tập ${ep.name}',
        embedUrl: ep.embed,
        episodes: s.items,
        startIndex: s.items.indexOf(ep),
        onEpisodeChange: (e) => ref.read(storeProvider).saveProgress(slug: d.slug, server: s.serverName, episodeSlug: e.slug, episodeName: e.name),
      ),
    ));
  }
}
```

- [ ] **Step 3: Chạy & kiểm tra**

Run: `flutter run -d windows`
Expected: Bấm 1 phim → màn chi tiết đủ thông tin, chọn server, thấy danh sách tập; nút Yêu thích đổi trạng thái. (Bấm tập sẽ lỗi import `PlayerScreen` cho tới Task 9 — làm Task 9 tiếp.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Detail screen (thông tin, server, tập, yêu thích, phim tương tự)"
```

---

## Task 9: Player screen (WebView hộp kín chặn quảng cáo) — MỐC QUAN TRỌNG

**Files:**
- Create: `lib/player/player_screen.dart`

**Interfaces:**
- Consumes: `flutter_inappwebview`, `ad_blocker.dart`, `Episode`.
- Produces: `PlayerScreen({required String title, required String embedUrl, required List<Episode> episodes, required int startIndex, required void Function(Episode) onEpisodeChange})` — full màn hình, WebView nạp embed với ContentBlocker + user script; thanh dưới chuyển tập.

- [ ] **Step 1: PlayerScreen**

`lib/player/player_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/episode.dart';
import '../theme/app_theme.dart';
import 'ad_blocker.dart';

class PlayerScreen extends StatefulWidget {
  final String title, embedUrl;
  final List<Episode> episodes;
  final int startIndex;
  final void Function(Episode) onEpisodeChange;
  const PlayerScreen({
    super.key, required this.title, required this.embedUrl,
    required this.episodes, required this.startIndex, required this.onEpisodeChange,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  InAppWebViewController? _c;
  late int _idx;
  late String _url;

  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex;
    _url = widget.embedUrl;
  }

  void _goto(int i) {
    if (i < 0 || i >= widget.episodes.length) return;
    final ep = widget.episodes[i];
    setState(() { _idx = i; _url = ep.embed; });
    widget.onEpisodeChange(ep);
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(ep.embed)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        // Thanh trên: back + tên
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_url)),
            initialSettings: InAppWebViewSettings(
              contentBlockers: adContentBlockers(),
              javaScriptCanOpenWindowsAutomatically: false,
              supportMultipleWindows: false,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            ),
            initialUserScripts: UnmodifiableListView([
              UserScript(source: kAntiAdUserScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
            ]),
            onWebViewCreated: (c) => _c = c,
            // Chặn điều hướng sang trang QC: chỉ cho phép trong khung phát/stream
            shouldOverrideUrlLoading: (c, action) async {
              final u = action.request.url?.toString() ?? '';
              if (isAdUrl(u)) return NavigationActionPolicy.CANCEL;
              return NavigationActionPolicy.ALLOW;
            },
            onCreateWindow: (c, req) async => false, // chặn mở cửa sổ QC
          ),
        ),
        // Thanh dưới: chuyển tập
        if (widget.episodes.length > 1)
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _idx > 0 ? () => _goto(_idx - 1) : null),
              Text('Tập ${widget.episodes[_idx].name}', style: const TextStyle(color: Colors.white)),
              IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _idx < widget.episodes.length - 1 ? () => _goto(_idx + 1) : null),
            ]),
          ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Import UnmodifiableListView**

Đầu file thêm nếu thiếu:
```dart
import 'dart:collection';
```

- [ ] **Step 3: Chạy & KIỂM TRA CHẶN QUẢNG CÁO (thủ công, kịch bản)**

Run: `flutter run -d windows`
Kịch bản kiểm thử:
1. Mở 1 phim → bấm "Xem ngay".
2. Xác nhận video phát được.
3. **Xác nhận KHÔNG có popup/tab quảng cáo bật lên** khi bấm vào vùng video.
4. **Xác nhận KHÔNG có banner/overlay quảng cáo** che video.
5. Với phim bộ: bấm ⏭ chuyển tập → video đổi đúng tập.
Expected: phát mượt, sạch quảng cáo. Nếu còn QC lọt: thêm domain vào `kAdHosts` (Task 4) rồi chạy lại.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Player WebView hộp kín + chặn quảng cáo + chuyển tập"
```

---

## Task 10: Browse + Lọc nâng cao (cuộn vô tận)

**Files:**
- Modify: `lib/screens/browse_screen.dart`
- Modify: `lib/state/providers.dart` (thêm `browseProvider` phân trang)

**Interfaces:**
- Consumes: `apiProvider`, catalog, `MovieCard`.
- Produces: `BrowseScreen` — chọn Loại/Thể loại/Quốc gia/Năm → lưới kết quả, tự tải trang tiếp khi cuộn cuối.

- [ ] **Step 1: State phân trang**

Thêm vào `lib/state/providers.dart`:
```dart
class BrowseQuery {
  final String kind; // 'type' | 'genre' | 'country' | 'year'
  final String value;
  const BrowseQuery(this.kind, this.value);
  @override
  bool operator ==(Object o) => o is BrowseQuery && o.kind == kind && o.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
}

class BrowseState {
  final List<Movie> items;
  final int page, totalPage;
  final bool loading;
  BrowseState({required this.items, required this.page, required this.totalPage, required this.loading});
}

class BrowseNotifier extends StateNotifier<BrowseState> {
  final NguoncApi api;
  final BrowseQuery q;
  BrowseNotifier(this.api, this.q) : super(BrowseState(items: [], page: 0, totalPage: 1, loading: false)) { loadMore(); }

  Future<void> loadMore() async {
    if (state.loading || state.page >= state.totalPage) return;
    state = BrowseState(items: state.items, page: state.page, totalPage: state.totalPage, loading: true);
    final next = state.page + 1;
    Paginated<Movie> res;
    switch (q.kind) {
      case 'type': res = await api.listByType(q.value, page: next); break;
      case 'genre': res = await api.byGenre(q.value, page: next); break;
      case 'country': res = await api.byCountry(q.value, page: next); break;
      default: res = await api.byYear(q.value, page: next);
    }
    state = BrowseState(items: [...state.items, ...res.items], page: next, totalPage: res.totalPage, loading: false);
  }
}

final browseProvider = StateNotifierProvider.family<BrowseNotifier, BrowseState, BrowseQuery>(
    (ref, q) => BrowseNotifier(ref.read(apiProvider), q));
```

- [ ] **Step 2: BrowseScreen**

`lib/screens/browse_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/catalog.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  BrowseQuery _q = const BrowseQuery('type', 'phim-bo');
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(browseProvider(_q).notifier).loadMore();
      }
    });
  }

  void _pick(BrowseQuery q) => setState(() => _q = q);

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(browseProvider(_q));
    return Column(children: [
      _filterBar(),
      Expanded(
        child: GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: st.items.length,
          itemBuilder: (c, i) {
            final m = st.items[i];
            return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
          },
        ),
      ),
      if (st.loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: kRed)),
    ]);
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        _group('Loại', [for (final t in kTypes) BrowseQuery('type', t.slug)], [for (final t in kTypes) t.label]),
        _group('Thể loại', [for (final g in kGenres) BrowseQuery('genre', g.slug)], [for (final g in kGenres) g.label]),
        _group('Quốc gia', [for (final c in kCountries) BrowseQuery('country', c.slug)], [for (final c in kCountries) c.label]),
        _group('Năm', [for (final y in kYears) BrowseQuery('year', y)], kYears),
      ]),
    );
  }

  Widget _group(String label, List<BrowseQuery> qs, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54)),
        for (int i = 0; i < qs.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: _q == qs[i],
              selectedColor: kRed,
              onSelected: (_) => _pick(qs[i]),
            ),
          ),
      ]),
    );
  }
}
```

- [ ] **Step 3: Chạy & kiểm tra**

Run: `flutter run -d windows`
Expected: Tab Duyệt → chọn thể loại/quốc gia/năm → lưới phim; cuộn xuống tự tải thêm.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Browse + lọc nâng cao + cuộn vô tận"
```

---

## Task 11: Search screen

**Files:**
- Modify: `lib/screens/search_screen.dart`
- Modify: `lib/state/providers.dart` (thêm `searchProvider`)

**Interfaces:**
- Consumes: `apiProvider`, `MovieCard`.
- Produces: `SearchScreen` — ô nhập, gọi search, lưới kết quả.

- [ ] **Step 1: searchProvider**

Thêm vào `lib/state/providers.dart`:
```dart
final searchProvider = FutureProvider.family<List<Movie>, String>((ref, q) async {
  if (q.trim().length < 2) return [];
  return ref.read(apiProvider).search(q.trim());
});
```

- [ ] **Step 2: SearchScreen**

`lib/screens/search_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import '../widgets/async_view.dart';
import 'detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tìm phim theo tên...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true, fillColor: kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => setState(() => _q = v),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: _q.trim().length < 2
            ? const Center(child: Text('Nhập ít nhất 2 ký tự để tìm', style: TextStyle(color: Colors.white38)))
            : AsyncView(
                value: ref.watch(searchProvider(_q)),
                onRetry: () => ref.invalidate(searchProvider(_q)),
                builder: (list) => list.isEmpty
                    ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final m = list[i];
                          return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
                        },
                      ),
              ),
      ),
    ]);
  }
}
```

- [ ] **Step 3: Chạy & kiểm tra**

Run: `flutter run -d windows`
Expected: Tab Tìm kiếm → gõ "goblin" → ra kết quả; bấm mở chi tiết.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: Search screen"
```

---

## Task 12: My List + hàng "Xem tiếp" ở Home

**Files:**
- Modify: `lib/screens/my_list_screen.dart`
- Modify: `lib/screens/home_screen.dart` (thêm hàng Xem tiếp trên cùng)

**Interfaces:**
- Consumes: `storeProvider`.
- Produces: `MyListScreen` (lưới yêu thích, rỗng thì báo); Home có hàng "Xem tiếp" nếu có tiến trình.

- [ ] **Step 1: MyListScreen**

`lib/screens/my_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';

class MyListScreen extends ConsumerWidget {
  const MyListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(storeProvider).favorites;
    if (favs.isEmpty) {
      return const Center(child: Text('Chưa có phim yêu thích.\nBấm ♥ ở trang chi tiết để lưu.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: 0.52, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: favs.length,
      itemBuilder: (c, i) {
        final m = favs[i];
        return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
      },
    );
  }
}
```

- [ ] **Step 2: Hàng "Xem tiếp" ở Home**

Trong `home_screen.dart`, trong `builder`, ngay sau `HeroBanner` thêm:
```dart
Builder(builder: (context) {
  final cw = ref.watch(storeProvider).continueWatching;
  if (cw.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Xem tiếp', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
      SizedBox(height: 60, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
        for (final p in cw)
          Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(
            label: Text('${p.slug}  ·  Tập ${p.episodeName}', style: const TextStyle(color: Colors.white)),
            onPressed: () => _open(context, Movie.fromJson({'name': p.slug, 'slug': p.slug, 'total_episodes': 0})),
          )),
      ])),
    ]),
  );
}),
```
> Ghi chú: nhấn "Xem tiếp" mở lại trang Chi tiết (từ đó chọn đúng tập). Đủ tốt cho Giai đoạn 1.

- [ ] **Step 3: Chạy & kiểm tra**

Run: `flutter run -d windows`
Kịch bản: thêm 1 phim vào Yêu thích → tab Yêu thích thấy nó. Xem 1 tập → về Home thấy hàng "Xem tiếp". Tắt app mở lại → cả hai vẫn còn.
Expected: đúng như trên.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: My List + hàng Xem tiếp ở Home"
```

---

## Task 13: Đóng gói ra .exe (bản phát hành)

**Files:** không sửa code; tạo bản build release.

**Interfaces:** Produces thư mục app chạy độc lập.

- [ ] **Step 1: Build release**

Run: `flutter build windows --release`
Expected: build thành công.

- [ ] **Step 2: Xác định thư mục output**

Thư mục: `build/windows/x64/runner/Release/` chứa `app_xem_phim.exe` + các file `.dll` + thư mục `data/`.

- [ ] **Step 3: Chạy thử bản release**

Mở `build/windows/x64/runner/Release/app_xem_phim.exe` (double-click).
Expected: App chạy độc lập, đủ chức năng, phát phim sạch QC.

- [ ] **Step 4: Đóng gói để copy sang máy khác (gia đình)**

Nén **toàn bộ** thư mục `Release/` thành `.zip`. Máy đích cần **Windows 10/11** và **WebView2 Runtime** (Windows 11 có sẵn; Windows 10 nếu thiếu thì cài "Microsoft Edge WebView2 Runtime" miễn phí). Giải nén và chạy `app_xem_phim.exe`.

- [ ] **Step 5: Commit ghi chú phát hành**

Tạo `README.md` ngắn (cách chạy + yêu cầu WebView2), rồi:
```bash
git add README.md
git commit -m "docs: hướng dẫn chạy bản .exe + yêu cầu WebView2"
```

---

## Self-Review (đối chiếu spec)

- **Flutter, một codebase:** ✔ Task 0–13 (lõi tách lớp để Giai đoạn 2 TV tái dùng).
- **Chặn QC WebView hộp kín 3 tầng:** ✔ Task 4 (blocklist + ContentBlocker + user script) & Task 9 (áp dụng, `onCreateWindow`/`shouldOverrideUrlLoading`).
- **Không tự giải mã stream:** ✔ Player nạp `embed`.
- **Netflix tiếng Việt đen/đỏ:** ✔ Task 5 theme + Task 6/7 UI.
- **Home banner + hàng ngang:** ✔ Task 7.
- **Duyệt + lọc nâng cao + cuộn vô tận:** ✔ Task 10.
- **Tìm kiếm:** ✔ Task 11.
- **Chi tiết + server + tập + phim tương tự:** ✔ Task 8.
- **Yêu thích + Xem tiếp (cục bộ):** ✔ Task 3 + Task 8 + Task 12.
- **Xử lý lỗi + Thử lại:** ✔ `AsyncView` (Task 5) dùng xuyên suốt.
- **User-Agent tránh 403:** ✔ Task 2 + Task 9.
- **Test lõi (API/models/store/adblock):** ✔ Task 1–4 TDD.
- **Đóng gói .exe cho gia đình:** ✔ Task 13.

Không còn placeholder; tên hàm/kiểu nhất quán giữa các task (`Movie`, `MovieDetail`, `ServerGroup`, `Episode`, `LocalStore`, `NguoncApi`, `browseProvider`, `detailProvider`...).
