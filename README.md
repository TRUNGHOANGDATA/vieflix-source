# App Xem Phim (Windows)

App xem phim giao diện kiểu Netflix (tiếng Việt, nền đen/đỏ), nguồn từ API nguonc,
phát video bằng WebView "hộp kín" chặn quảng cáo. Dùng cho gia đình.

## Cách chạy nhanh
Mở file:
```
build\windows\x64\runner\Release\app_xem_phim.exe
```
(hoặc dùng shortcut "App Xem Phim" ngoài Desktop.)

## Yêu cầu máy
- Windows 10/11 (64-bit).
- **Microsoft Edge WebView2 Runtime** (Windows 11 có sẵn). Nếu máy khác thiếu,
  tải miễn phí "Microsoft Edge WebView2 Runtime" từ trang Microsoft và cài.

## Chép sang máy khác (cho gia đình)
Nén **toàn bộ** thư mục `build\windows\x64\runner\Release\` thành `.zip`,
copy sang máy đích, giải nén, rồi chạy `app_xem_phim.exe`.
(Máy đích cần WebView2 Runtime như trên.)

## Chức năng
- Trang chủ: banner lớn + các hàng phim cuộn ngang.
- Duyệt & lọc nâng cao (Loại / Thể loại / Quốc gia / Năm), cuộn vô tận.
- Tìm kiếm theo tên.
- Chi tiết phim: thông tin, chọn server (Vietsub/Lồng tiếng), danh sách tập, phim tương tự.
- Xem phim: trình phát chặn quảng cáo, chuyển tập.
- Yêu thích (My List) + Xem tiếp — lưu ngay trên máy.

## Dành cho người phát triển
- Flutter (Windows desktop). `flutter pub get` rồi `flutter run -d windows`.
- Build bản phát hành: `flutter build windows --release`.
- Lưu ý: plugin `flutter_inappwebview` cần **NuGet** trên PATH khi build
  (đã đặt `nuget.exe` trong `H:\flutter\bin`).
- Tài liệu thiết kế & kế hoạch: thư mục `docs/superpowers/`.
- Giai đoạn 2 (app Android TV) sẽ tái sử dụng phần lõi trong `lib/`.
