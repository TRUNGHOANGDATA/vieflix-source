# Kế hoạch: thêm nguồn phim thứ hai + đổi nguồn / đổi tiếng trong trình phát

Ngày lập: 25/08/2026. Trạng thái: **chưa bắt đầu**, đang chờ chốt phạm vi.

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
