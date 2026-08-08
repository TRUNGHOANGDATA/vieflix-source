# Thiết kế: App Xem Phim (Máy tính + Android TV)

**Ngày:** 2026-08-08
**Nguồn phát:** https://phim.nguonc.com (API công khai)
**Mục tiêu:** App xem phim giao diện kiểu Netflix, tiếng Việt, nền tối (đen/đỏ), dùng cho gia đình. Xây app máy tính (Windows) trước, sau đó tái sử dụng để ra app Android TV.

---

## 1. Tổng quan & Quyết định chính

- **Công nghệ:** Flutter — một bộ mã nguồn xuất ra **cả `.exe` (Windows)** lẫn **`.apk` (Android TV)**, tái sử dụng ~80% code.
- **Kiến trúc trình phát (quan trọng nhất):** Stream của streamc.xyz là HLS **mã hóa riêng** (`AES-GCM` + `EXT-X-B65`), chỉ giải mã được bằng jwplayer + bộ giải mã của họ. Vì vậy **không tự bóc link m3u8** (dễ vỡ khi họ đổi thuật toán). Thay vào đó, phát bằng **WebView "hộp kín"** do app kiểm soát 100%, với **lớp chặn quảng cáo** (chặn domain, chặn popup, ẩn overlay).
- **Lưu dữ liệu cá nhân:** hoàn toàn **cục bộ trên máy** (không server, không đăng nhập).
- **Phạm vi:** dùng cá nhân/gia đình. Không phát hành công khai (không cần hạ tầng phân phối phức tạp).

### Lưu ý pháp lý/đạo đức
App chỉ là một trình duyệt/trình phát cá nhân đọc từ API công khai của nguonc, phục vụ nhu cầu xem cá nhân — tương tự dùng trình duyệt có chặn quảng cáo. Không lưu trữ, không phát tán lại nội dung phim.

---

## 2. Kiến trúc tổng thể

Chia thành các lớp độc lập, mỗi lớp một nhiệm vụ rõ ràng:

```
┌─────────────────────────────────────────────┐
│  UI (Màn hình Netflix-style)                 │  ← Flutter widgets
│  Home · Duyệt/Lọc · Tìm kiếm · Chi tiết ·    │
│  Player · My List                            │
├─────────────────────────────────────────────┤
│  State / Điều khiển (quản lý trạng thái)     │  ← Riverpod
├─────────────────────────────────────────────┤
│  Nguồn dữ liệu                               │
│  ┌──────────────┐   ┌──────────────────────┐│
│  │ NguoncApi    │   │ LocalStore           ││
│  │ (gọi HTTP,   │   │ (Yêu thích,          ││
│  │  parse JSON) │   │  Xem tiếp — cục bộ)  ││
│  └──────────────┘   └──────────────────────┘│
├─────────────────────────────────────────────┤
│  Player Engine                               │
│  WebView hộp kín + AdBlocker (chặn QC)       │
└─────────────────────────────────────────────┘
```

### Thành phần & trách nhiệm

| Thành phần | Làm gì | Phụ thuộc |
|---|---|---|
| `NguoncApi` | Gọi API, trả về đối tượng phim đã parse. Không biết gì về UI. | `http` |
| `Movie` / `MovieDetail` / `Episode` (models) | Cấu trúc dữ liệu thuần. | — |
| `LocalStore` | Đọc/ghi Yêu thích + Xem tiếp xuống máy. | `shared_preferences` (hoặc `hive`) |
| `AdBlocker` | Danh sách domain chặn + script/CSS tiêm vào WebView. | — |
| `PlayerScreen` | Nhúng WebView, áp AdBlocker, quản lý full màn hình, chuyển tập. | `webview_windows` (PC) / `webview_flutter` (Android) |
| UI Screens | Hiển thị, điều hướng, focus cho remote. | State layer |

Mỗi lớp có ranh giới rõ: đổi giao diện không đụng API; đổi cách chặn QC không đụng UI; thêm màn hình mới không đụng player.

---

## 3. API nguonc (đã kiểm chứng 200 OK)

- **Base:** `https://phim.nguonc.com/api`
- Header gọi kèm `User-Agent` trình duyệt để tránh 403.

| Mục đích | Endpoint |
|---|---|
| Mới cập nhật (phân trang) | `/films/phim-moi-cap-nhat?page=N` |
| Danh sách theo loại | `/films/danh-sach/{phim-bo\|phim-le\|hoat-hinh\|tv-shows}?page=N` |
| Theo thể loại | `/films/the-loai/{slug}?page=N` |
| Theo quốc gia | `/films/quoc-gia/{slug}?page=N` |
| Theo năm | `/films/nam-phat-hanh/{year}?page=N` |
| Tìm kiếm | `/films/search?keyword={q}` |
| Chi tiết phim | `/film/{slug}` |

**Cấu trúc danh sách:** `{ status, paginate:{current_page,total_page,...}, items:[{name,slug,thumb_url,poster_url,description,total_episodes,current_episode,quality,language,...}] }`

**Cấu trúc chi tiết** (`movie`): các trường trên + `category` (nhóm: Định dạng / Thể loại / Năm / Quốc gia) + `episodes:[{ server_name, items:[{name, slug, embed}] }]`.
- `embed` = URL iframe (vd `https://embed14.streamc.xyz/embed.php?hash=...`) → đây là thứ nạp vào WebView player.

*Danh sách slug thể loại/quốc gia dùng cho bộ lọc sẽ được chốt (danh sách cố định, tiếng Việt) trong lúc lập trình.*

---

## 4. Các màn hình (chi tiết)

### 4.1 Home
- **Banner hero** đầu trang: poster lớn 1 phim nổi bật (lấy từ "mới cập nhật"/random), có tên, mô tả rút gọn, nút **▶ Xem**, **+ Yêu thích**. Tự đổi phim mỗi ~8s.
- **Các hàng cuộn ngang** (mỗi hàng gọi 1 endpoint): *Xem tiếp* (nếu có) → *Mới cập nhật* → *Phim bộ* → *Phim lẻ* → *Hoạt hình* → *TV Shows* → vài hàng thể loại hot.
- Poster: hover (PC)/focus (TV) → phóng to nhẹ + hiện tên.

### 4.2 Duyệt & Lọc nâng cao
- Tab loại phim + panel lọc kết hợp **Thể loại × Quốc gia × Năm × Sắp xếp**.
- Kết quả lưới, **cuộn vô tận** (tự tải `page` kế tiếp).

### 4.3 Tìm kiếm
- Ô nhập → gọi `/films/search`. Trên TV: bàn phím ảo điều khiển bằng remote.

### 4.4 Chi tiết phim
- Nền poster lớn + thông tin (năm, chất lượng, quốc gia, thể loại, đạo diễn, diễn viên, mô tả).
- **+ Yêu thích**. **Danh sách tập** + **chọn server** (Vietsub/Lồng tiếng).
- Hàng "Phim tương tự" (cùng thể loại đầu tiên).

### 4.5 Player (hộp kín chặn QC) — xem mục 5
- Full màn hình, nhớ vị trí/tập, nút chuyển tập & đổi server.

### 4.6 My List
- Lưới các phim đã Yêu thích (đọc từ LocalStore).

---

## 5. Player Engine & Chặn quảng cáo (trọng tâm)

**Luồng:** Chi tiết phim → chọn tập/server → lấy `embed` URL → mở `PlayerScreen` → WebView nạp `embed` trong môi trường app kiểm soát.

**Lớp chặn quảng cáo (AdBlocker) gồm 3 tầng:**
1. **Chặn request theo domain:** WebView chặn nạp tài nguyên từ danh sách domain quảng cáo/tracker (vd mạng `_wau`/widget QC, popunder, analytics). Request khớp danh sách → hủy.
2. **Chặn popup/popunder:** tiêm JS ghi đè `window.open = ()=>null`, chặn `target=_blank`, chặn chuyển hướng ngoài ý muốn.
3. **Dọn giao diện:** tiêm CSS/JS ẩn các phần tử overlay/banner/logo QC, ép `<video>`/khung phát chiếm toàn màn hình; vô hiệu vòng lặp `location.reload()` do anti-devtools của trang (tiêm stub cho `devtoolsDetector`).

**Kết quả kỳ vọng:** vào là phát, không popup, không lớp QC che video.

**Rủi ro & phương án dự phòng:** nếu nguồn đổi cấu trúc → cập nhật danh sách chặn/CSS (dữ liệu, không phải viết lại app). Nếu 1 server lỗi → cho người dùng đổi sang server khác (Vietsub/Lồng tiếng) ngay trong player.

**Khác biệt nền tảng:**
- **Windows:** `webview_windows` (dựa trên WebView2 — có sẵn trên Windows 11).
- **Android TV:** `webview_flutter` (WebView hệ thống Android). Cùng một logic AdBlocker, chỉ khác cách gắn.

---

## 6. Lưu dữ liệu cục bộ

| Dữ liệu | Nội dung |
|---|---|
| **Yêu thích** | Danh sách `{slug, name, poster_url}` phim đã lưu. |
| **Xem tiếp** | Theo `slug`: `{server, tập đang xem, thời điểm cập nhật}`. |

- Lưu bằng `shared_preferences`/`hive`. Không cần internet cho phần này, không rời khỏi máy.

---

## 7. Điều khiển & Điều hướng

- **Windows:** chuột + phím tắt (mũi tên, Enter chọn, Esc thoát/back, Space play-pause).
- **Android TV (giai đoạn 2):** toàn bộ dùng **D-pad remote** — mọi phần tử có focus rõ ràng (viền sáng), lưới/hàng điều hướng bằng mũi tên, OK để chọn, Back để quay lại. Thiết kế widget có `Focus`/`FocusNode` ngay từ đầu để không phải làm lại.

---

## 8. Xử lý lỗi

- **Mất mạng / API lỗi:** hiện thông báo thân thiện + nút "Thử lại". Không sập app.
- **403 từ nguồn:** luôn gửi kèm `User-Agent`; nếu vẫn lỗi → thông báo nguồn tạm chặn.
- **Server phát lỗi:** gợi ý đổi server khác trong player.
- **Không có tập/embed:** báo "phim chưa có nguồn phát".

---

## 9. Kiểm thử (Testing)

- **Unit test:** `NguoncApi` (parse JSON đúng cho list & detail, xử lý lỗi mạng); `LocalStore` (ghi/đọc Yêu thích, Xem tiếp); logic khớp domain của `AdBlocker`.
- **Kiểm thử thủ công có kịch bản:** duyệt Home, lọc, tìm kiếm, mở chi tiết, phát 1 tập và xác nhận **không thấy quảng cáo/popup**, chuyển tập, đổi server, thêm/xóa Yêu thích, tắt-mở app thấy "Xem tiếp".
- Áp dụng TDD cho lớp API & LocalStore (logic thuần, dễ test).

---

## 10. Lộ trình (phân giai đoạn)

**Giai đoạn 1 — App Máy tính (Windows):**
1. Khởi tạo dự án Flutter + cài công cụ build Windows.
2. Lớp `NguoncApi` + models (có test).
3. `LocalStore` (có test).
4. Khung điều hướng + theme đen/đỏ.
5. Home (banner + hàng ngang).
6. Chi tiết phim.
7. Player + AdBlocker (chặn QC) — mốc quan trọng, kiểm thử kỹ.
8. Duyệt/Lọc + Tìm kiếm + My List + Xem tiếp.
9. Đóng gói ra `.exe`.

**Giai đoạn 2 — App Android TV:** tái sử dụng lõi; thêm điều hướng D-pad, WebView Android, bàn phím ảo TV; đóng gói `.apk`. (Sẽ lập spec riêng khi tới giai đoạn này.)

---

## 11. Ngoài phạm vi (YAGNI)

- Không tài khoản người dùng/đăng nhập, không đồng bộ đám mây.
- Không tải phim offline.
- Không nhiều hồ sơ (profiles) như Netflix.
- Không macOS/Linux/iOS ở giai đoạn này (chỉ Windows + Android TV).
- Không tự giải mã stream (dùng WebView hộp kín thay thế).
