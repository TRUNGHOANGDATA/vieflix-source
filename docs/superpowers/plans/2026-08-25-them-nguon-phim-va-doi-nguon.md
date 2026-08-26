# Kế hoạch: thêm nguồn phim thứ hai + đổi nguồn / đổi tiếng trong trình phát

Ngày lập: 25/08/2026. Trạng thái: **xong P1 → P4**. P3 chỉ bật trên Windows
(xem "Tình hình" ở cuối).

## Yêu cầu của user

1. Thêm nguồn phát nữa; **phim nào nguonc không có thì lấy từ nguồn mới**.
2. Trong mỗi phim cho phép **chọn nguồn**.
3. Trình phát có nút **đổi nguồn** và **đổi Thuyết minh / Vietsub**.

## Khảo sát đã làm (25/08/2026)

### Nguồn KHÔNG dùng — chủ site chặn
| Site | robots.txt |
|---|---|
| `vieflix.top` | `User-agent: ClaudeBot → Disallow: /` **và** `Disallow: /api/` cho mọi bot |
| `ophim1.com` | `User-agent: ClaudeBot → Disallow: /` |

Hai site này **không lấy dữ liệu, không đọc code, không dò API**. Cũng lưu ý:
vieflix.top chỉ là front-end Next.js — "lắm source" của họ nằm ở API phía sau, nên
sao chép code trang cũng không thêm được phim nào.

### Nguồn sẽ dùng: `phimapi.com`
- robots.txt chỉ có phần chú thích mẫu của Cloudflare, **không có chỉ thị chặn nào**.
- Kho phim: **29.813 phim / 1.243 trang** (nguonc ít hơn nhiều).
- **Dùng endpoint `/v1/api/...`**, không dùng `/danh-sach/...` cũ: bản v1 trả kèm
  `lang`, `category`, `country`, `episode_current`, `quality`, `type`, `imdb`, `tmdb`;
  bản cũ chỉ có tên/slug/poster/year.
- Chi tiết phim: `GET /phim/{slug}` → `movie{}` + `episodes[].server_data[]`, mỗi tập
  có **cả `link_m3u8` và `link_embed`**.
- Tìm kiếm: `GET /v1/api/tim-kiem?keyword=...&limit=...`
- `link_m3u8` tải được **HTTP 200 mà không cần Referer**, là HLS master playlist
  (đo thử: 1920x1040, 3500kbps).
- Mỗi phim thường **chỉ 1 server**, nhưng trường `lang` có đủ loại — đếm trên một
  trang mẫu: 18 `Vietsub`, 5 `Vietsub + Thuyết Minh`, 1 `Lồng Tiếng`.

### Vì sao `link_m3u8` là điểm đáng giá nhất
Có link video trực tiếp thì phát được bằng **trình phát native**, và cả một lớp lỗi
đã đánh nhau suốt 19–20/08 tự biến mất: không trang embed nên không quảng cáo,
không thanh JWPlayer phải giấu bằng CSS, không cần cầu nối JS (plugin
`flutter_inappwebview_windows` 0.6.0 không tiêm user script — xem `player_screen.dart`),
không bị WebView2 chiếm tiêu điểm bàn phím, vị trí xem đọc chính xác từng giây,
và không cần script ép autoplay.

## Kiến trúc: quy về MỘT danh sách "nguồn phát" phẳng

Đây là chỗ giải quyết gọn cả 3 yêu cầu bằng một mô hình:

```dart
class StreamSource {
  final String provider;    // 'nguonc' | 'phimapi'
  final String serverName;  // 'Vietsub #1', 'Thuyết minh', ...
  final String lang;        // Vietsub / Thuyết Minh / Lồng Tiếng
  final StreamKind kind;    // embed (WebView) | hls (player native)
  final List<Episode> episodes;
}
```

- Chi tiết phim của nguonc có N nhóm server → N `StreamSource` (kind = embed).
- Chi tiết phim của phimapi → 1–2 `StreamSource` (kind = hls nếu có m3u8, không thì embed).
- **Trang chi tiết**: chip nguồn = `nguonc · Thuyết minh`, `phimapi · Vietsub (HLS)`...
  → đúng yêu cầu 2 và 3 cùng lúc, vì với các site này "Thuyết minh / Vietsub"
  **là hai bản upload khác nhau, không phải audio track trong một file**.
- **Trình phát**: nhận đúng danh sách đó + nút đổi → yêu cầu 3.

## Các giai đoạn

### P1 — Lớp nguồn + gộp danh mục (chưa đụng trình phát)
- Tách `abstract class MovieSource` với đúng các phép app đang dùng:
  `latest`, `listByType`, `byGenre`, `byCountry`, `byYear`, `search`, `detail`.
- `NguoncApi` thành một implementation; thêm `PhimApiSource`.
- Adapter map dữ liệu phimapi về `Movie` / `MovieDetail` / `Episode` hiện có.
- **Gộp danh mục:** nguonc trước, phim nào nguonc chưa có thì lấy phimapi bù vào.
- Cài đặt: bật/tắt từng nguồn.
- Xong P1 là có ~30k phim mà **không phải sửa trình phát**.

### P2 — Chọn nguồn trong phim + đổi nguồn trong trình phát
- Dựng `StreamSource` như trên; trang chi tiết hiện chip nguồn kèm tên nhà cung cấp.
- Trình phát: thêm nút "Nguồn" trên thanh điều khiển → bảng chọn (kiểu bảng chọn
  của `TvFilterBar`, D-pad bấm được).
- Đổi nguồn phải **giữ nguyên tập và vị trí đang xem**.
- P2 vẫn chạy trên WebView cho cả hai nhà cung cấp (phimapi có `link_embed`), nên
  **có tính năng đổi nguồn mà chưa cần làm player native**.

### P3 — Trình phát native cho m3u8
- Thêm `media_kit` (chạy được cả Windows và Android, có tăng tốc phần cứng).
- Dùng lại đúng giao diện đã làm (logo góc `ChannelBug`, thanh điều khiển) nhưng gắn
  vào player thật → **bỏ được cầu nối JS, code ít hơn hẳn**.
- Giữ nguyên đường WebView cho nguonc và cho phim phimapi chỉ có embed.
- Ưu tiên hls khi có; embed là dự phòng.

### P4 — Mở rộng
- Tìm kiếm gộp hai nguồn, lọc trùng.
- Lọc theo dữ liệu phong phú hơn của phimapi (`quality`, `lang`, `imdb`).

## Những chỗ dễ sai — đã lường trước

| Chỗ | Cách xử lý |
|---|---|
| **Khoá gộp/lọc trùng** | Slug hai bên KHÔNG đảm bảo giống nhau → khoá chính = `bỏ dấu(name)` + `year`; slug chỉ là đường tắt kiểm nhanh |
| **Phân trang 2 nguồn** | `BrowseNotifier` phải giữ **2 con trỏ trang riêng**, không dùng chung một số trang |
| **Slug thể loại / quốc gia khác nhau** | `kGenres`/`kCountries` đang hardcode theo nguonc → phải map sang slug của phimapi (hoặc lấy danh sách từ API của họ) |
| **Đổi nguồn giữa phim** | Số tập và cách đặt tên tập khác nhau giữa hai nguồn → map theo **SỐ tập** trích từ tên; không tìm được tập tương ứng thì báo rõ chứ đừng phát sai tập |
| **Đổi giữa hls và embed** | Đổi cả backend phát → màn trình phát phải chứa được **cả hai** loại và đổi lúc đang chạy |
| **`media_kit` làm APK phình** | Kéo theo libmpv — **phải đo trước khi hứa**, có thể +20–40MB. Nếu quá lớn thì cân nhắc chỉ bật native trên Windows |
| **Host m3u8 đổi / hết hạn** | Luôn giữ `link_embed` làm đường dự phòng, tự chuyển khi hls lỗi |
| **Trình phát đang có 22 test** | Không phá: thêm nguồn mới là thêm implementation, không sửa hành vi cũ. Test hiện có phải vẫn xanh sau mỗi giai đoạn |

## Đề xuất thứ tự

Làm **P1 → dừng lại kiểm** (xem chất lượng phim và độ ổn của nguồn mới) → P2 → P3.
Lý do không làm P3 sớm: `media_kit` là thay đổi lớn nhất và tốn nhất, nên chỉ bỏ công
sau khi đã biết chắc nguồn mới đáng giá.

---

## Tình hình (cập nhật 25/08/2026)

### Đã xong

**P1 — lớp nguồn + gộp danh mục.**
`lib/data/movie_source.dart` (giao diện chung + lọc trùng), `phimapi_source.dart`,
`aggregate_source.dart`. Bật/tắt nguồn ở Cài đặt; phim đã lưu vẫn mở được cả khi
tắt nguồn (chi tiết đi theo `detailSources`, danh mục đi theo `sources`).

**P2 — chọn nguồn + đổi nguồn trong trình phát.**
`lib/models/stream_source.dart` + `lib/data/stream_sources.dart`. Trang chi tiết
gộp mọi lựa chọn thành một danh sách phẳng, chip ghi `nguonc · Thuyết minh`.
Trình phát có nút "Nguồn" mở bảng chọn (D-pad bấm được), đổi nguồn giữ nguyên tập
và vị trí đang xem.

**P4 — phần làm được ngay.**
Tìm kiếm gộp hai nguồn + lọc trùng đã nằm sẵn trong P1. Thêm lọc theo chất lượng
(`Movie.qualityTag`, `QualityFilterRow`) ở trang "Xem tất cả".
**Không làm lọc theo IMDb**: chỉ phimapi trả điểm imdb, làm bộ lọc đó thì mọi phim
nguonc biến mất — bộ lọc hỏng ngầm còn tệ hơn không có. App đã có điểm TMDB rồi.

### Sửa được hai lỗi lộ ra khi chạy thật

| Lỗi | Chi tiết |
|---|---|
| Tìm kiếm lọt phim trùng | Endpoint tìm kiếm của nguonc **không trả `year`**, mà khoá gộp lại là tên+năm. Đổi sang `MergeDedup`: thiếu năm ở một bên thì coi trùng tên là trùng phim |
| "Hài" và "Viễn Tưởng" ra 0 phim | Slug thật của nguonc là `phim-hai` và `khoa-hoc-vien-tuong`, không phải `hai`/`vien-tuong`. Đây là lỗi CÓ SẴN từ trước, không phải do thêm nguồn. Đã map slug ở cả hai nguồn |

### Đo thật với API (`dart run tool/smoke_sources.dart`)

```
latest p1          32 phim (nguonc 10 / phimapi 22)
genre hai          17 phim (nguonc 10 / phimapi  7)   <- trước đây nguonc 0
country han-quoc   12 phim (nguonc 10 / phimapi  2)   <- 8 phim trùng, đã kiểm tay: trùng thật

Sếp Chính Là Thần Tượng (2026)
   nguonc · Vietsub         8 tập  embed
   nguonc · Thuyết minh     8 tập  embed
   phimapi · Vietsub        7 tập  hls+embed
   phimapi · Thuyết minh    7 tập  hls+embed
   đổi nguồn: "nguonc · Vietsub" tập "2" -> "phimapi · Thuyết minh" tập "Tập 02"
```

46 test xanh, `flutter analyze` không lỗi.

**P3 — trình phát native cho m3u8 (CHỈ Windows).**
`media_kit` + `media_kit_video`. Phim có `link_m3u8` thì phát thẳng bằng libmpv,
không qua trang embed. Dùng lại nguyên thanh điều khiển + logo góc đã có
(`controls: NoVideoControls`), nên bỏ được cầu nối JS trên đường này.

- `_canNative(ep)` = `Platform.isWindows && ep.m3u8.isNotEmpty` → Android/TV giữ
  nguyên đường WebView, **APK không đổi dung lượng**.
- Vị trí / thời lượng / trạng thái phát đọc từ luồng của player, không dò JS mỗi giây.
- hls hỏng → `_fallbackToEmbed()` tự quay về `link_embed`, giữ chỗ đang xem.
- Đổi tập là cho thử lại đường hls (tập trước hỏng không suy ra tập này hỏng).
- Chọn nguồn mặc định (`defaultSourceIndex`): tiếng Việt trước, trong cùng loại
  tiếng thì ưu tiên bản phát thẳng.

### Đo dung lượng (điều kiện kế hoạch đặt ra trước khi làm P3)

| | Trước | Sau |
|---|---|---|
| Gói cài Windows | ~33 MB | **80 MB** |
| APK Android | không đổi | không đổi (native tắt trên Android) |

Phình thêm ~47 MB: `libmpv-2.dll` 29, `libGLESv2.dll` 8, `vk_swiftshader.dll` 5,
`d3dcompiler_47.dll` 5, còn lại là dll nhỏ.

### Kiểm thật

- `dart run tool/smoke_native.dart <m3u8>` → libmpv mở được link thật, đọc đúng
  thời lượng 4258s (≈71 phút, khớp "70 phút/tập"), `playing: true`.
- Bản Release chạy 15s ổn định, nạp đủ `libmpv-2.dll` + `WebView2Loader.dll`
  (cả hai đường phát cùng có mặt), RAM ~157 MB.

### Ghi chú môi trường

`flutter build apk --release` trên máy này chết ở
`java.io.IOException: Unable to establish loopback connection` — Gradle không mở nổi
socket loopback. Lỗi xảy ra **trên code chưa sửa gì**, trong lẫn ngoài sandbox → lỗi
môi trường máy. Vì vậy **bản Android chưa dựng thử lần nào** sau loạt thay đổi này.

### Chưa làm — và vì sao

**Không thêm `vsphim` (`v9.streamvsmov.com`) và `vicdn` (`vicdn.cc`).** Hai cái này
không phải nguồn phim mà là **host phát**: chúng không có danh mục để hỏi
(`latest`/`byGenre`/`search`...), `vicdn` chỉ là khuôn URL tra theo TMDB id. Cắm vào
làm `MovieSource` thì mọi hàng phim sẽ rỗng. Muốn dùng thì phải mò ngược giao thức
embed của chúng từ việc mổ xẻ `vieflix.top` — trang có `robots.txt` chặn ClaudeBot,
nên không làm. Nguồn nào có API công khai thì cắm thêm rất nhanh vì lớp
`MovieSource` đã dựng sẵn.
