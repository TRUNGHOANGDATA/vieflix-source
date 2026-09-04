#!/bin/bash
# Dựng file cài iPad (.ipa) cho VieFlix trên máy Mac.
#
# CẦN: macOS + Xcode (mở Xcode một lần cho nó cài xong Command Line Tools)
#      + Flutter SDK (https://docs.flutter.dev/get-started/install/macos)
#
# CHẠY: bash tool/build-ipa-mac.sh
# XONG: file build/ios/iphoneos/VieFlix.ipa — gửi lại cho chủ máy.
#
# .ipa này CHƯA KÝ, đúng như vậy: Sideloadly/AltStore sẽ ký bằng Apple ID của
# người cài. Script làm sẵn hai việc mà thiếu nó AltStore sẽ báo "isn't in the
# correct format": cắt binary về một kiến trúc, và ad-hoc ký lại.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "LỖI: chưa có Flutter trong PATH."; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "LỖI: chưa có Xcode Command Line Tools."; exit 1; }

echo "==> Flutter: $(flutter --version | head -1)"
flutter pub get
# Khóa TMDB nhúng lúc build (không nằm trong mã nguồn). Không có cũng chạy,
# chỉ là thiếu điểm đánh giá cho tới khi người dùng nhập khóa ở Cài đặt.
DEFINE=""
if [ -n "${TMDB_KEY:-}" ]; then DEFINE="--dart-define=TMDB_KEY=$TMDB_KEY"; fi
flutter build ios --release --no-codesign $DEFINE

APP=build/ios/iphoneos/Runner.app

# `ldid` mà AltStore dùng chỉ đọc được Mach-O MỘT kiến trúc. Bản build để lại
# vài binary "fat"; ldid đọc header fat như header thường rồi vỡ:
#   ldid.cpp(1461): _assert(): end >= size - 0x10
echo "==> Cắt binary về arm64"
thin_one() {
  local f="$1"; [ -f "$f" ] || return 0
  if lipo -info "$f" 2>/dev/null | grep -q "Architectures in the fat file"; then
    echo "    $f"
    lipo "$f" -thin arm64 -output "$f.thin" && mv -f "$f.thin" "$f"
  fi
}
thin_one "$APP/Runner"
if [ -d "$APP/Frameworks" ]; then
  for fw in "$APP"/Frameworks/*.framework; do
    [ -d "$fw" ] || continue
    thin_one "$fw/$(basename "$fw" .framework)"
  done
  for dy in "$APP"/Frameworks/*.dylib; do thin_one "$dy"; done
fi
echo "==> Còn file fat nào không (phải TRỐNG):"
find "$APP" -type f -exec sh -c 'lipo -info "$1" 2>/dev/null | grep -q "fat file" && echo "    CÒN FAT: $1"' _ {} \; || true

# Bản --no-codesign để lại chữ ký dở ở các framework, ldid cũng vỡ vì nó.
# KHÔNG xoá _CodeSignature — thiếu nó còn vỡ nặng hơn.
echo "==> Ad-hoc ký lại"
if [ -d "$APP/Frameworks" ]; then
  find "$APP/Frameworks" -name "*.dylib" -exec codesign --force --sign - {} \;
  find "$APP/Frameworks" -maxdepth 1 -name "*.framework" -exec codesign --force --sign - {} \;
fi
codesign --force --sign - "$APP"

# ditto chứ không phải zip: AltStore hay không đọc được file do `zip` tạo.
echo "==> Đóng gói .ipa"
cd build/ios/iphoneos
rm -rf Payload VieFlix.ipa
mkdir -p Payload
cp -R Runner.app Payload/Runner.app
ditto -c -k --norsrc --noextattr --keepParent Payload VieFlix.ipa
rm -rf Payload

echo
echo "XONG: $(pwd)/VieFlix.ipa  ($(du -h VieFlix.ipa | cut -f1))"
echo "Gửi file này về là cài được bằng Sideloadly/AltStore."
