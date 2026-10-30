---
name: sua-nguonc
description: Chẩn đoán và vá khi phim nguồn nguonc (phim.nguonc.com / streamc.xyz) hỏng — không mở được trang phát, bị đá sang phim.nguonc.com, Cloudflare "you have been blocked", quảng cáo không bỏ qua được, phim đứng/quay mãi. Dùng khi user báo lỗi "nguồn C", nguonc, hoặc gửi ảnh bảng "Không mở được trang phát của nguồn này".
---

# Sửa nguồn nguonc

nguonc là nguồn hỏng nhiều nhất: chủ trang (streamc.xyz) đổi trình phát và lớp bảo vệ
liên tục (r25 tháng 10/2026: dò DevTools, quảng cáo `tvc`, dò chặn QC). Lần nào cũng đi
đúng 4 bước dưới — đừng đoán.

## 1. Chắc rằng user chạy bản build MỚI
User hay chạy `build\windows\x64\runner\Release\VieFlix.exe`. So giờ `data\app.so` với
giờ sửa code gần nhất; cũ thì build lại (`flutter build windows --release` bằng Bash,
đóng VieFlix.exe trước) rồi nhờ thử lại. Log của bản cũ trông y như lỗi chưa sửa.

## 2. Đọc nhật ký
Windows: `%APPDATA%\VieFlix\VieFlix\player-debug.log` (Android: `tool/tv.ps1 log`; iPad:
app Files). Tìm:
- `dung WebView voi url=<link embed>` — link để tái hiện ở bước 3.
- `CHAN quang cao cuop trang -> https://phim.nguonc.com/` + `CONNECTION_ABORTED`, trước đó
  `"/stream-guard/"` → trang tưởng có DevTools (bẫy console.debug), xem CLAUDE.md.
- `HTTP 403` khung chính / trang Cloudflare → mất Referer (Android: Referer gắn thẳng
  header; Windows/iPad: qua `RefererGate`).
- Dòng `trang nguonc sau 7s/20s: {...}` — đầu dò `_kNguoncProbeJs`: `jwState`, `vErr`,
  `popupReady`, `net` (request hỏng), `vBuf` (0 = chưa nạp được dữ liệu).

## 3. Tái hiện trên Edge (không cần build app)
```bash
python tool/nguonc_repro.py "<link embed>"                    # trang sạch
python tool/nguonc_repro.py "<link embed>" --app              # kèm kAntiAdUserScript
python tool/nguonc_repro.py "<link embed>" --dump <thư mục>   # lưu JS của trang để đọc
```
In tiếng Việt cần `PYTHONIOENCODING=utf-8`. Đạt khi `--app` ở lại streamc.xyz, `jw=playing`,
`t` tăng. Đọc JS đã lưu: `npx --yes prettier@3 --parser babel <file>`, grep `location.replace`,
`detect`, `JSON.parse`, cấu hình trong `#stream-bootstrap`.
`curl` vô dụng (luôn 403). Lỗi chỉ có trên iPad → `tool/webkit-repro/` (runner macOS).

## 4. Vá
- Chỗ vá: `kAntiAdUserScript` trong `lib/player/ad_blocker.dart` (chạy đầu trang, mọi
  khung). Cách đã chạy: móc `JSON.parse` sửa cấu hình phát; no-op console; cửa sổ giả cho
  `window.open`.
- Lỗi ở phía app (điều hướng, bảng lỗi, Referer) → `lib/player/player_screen.dart`
  (`shouldOverrideUrlLoading`, `onReceivedError`, `_setEmbedUrl`) và `lib/data/referer_gate.dart`.
- Đọc mục "Bài học ở trình phát — ĐỪNG đảo lại" trong CLAUDE.md TRƯỚC khi sửa.
- Thêm test chuỗi vào `test/ad_blocker_test.dart`; `flutter analyze lib test` + `flutter test`.
- Chạy lại bước 3 với `--app` để xác nhận, build bản Windows mới, mở cho user thử.
- User ưng thì phát hành theo skill `release-vieflix`.
