import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_xem_phim/player/channel_bug.dart';

/// Bọc widget trong khung tối giống lúc xem phim.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(backgroundColor: Colors.black, body: child),
    );

void main() {
  testWidgets('IN HOA HẾT: tên phim truyền vào kiểu thường vẫn ra chữ hoa',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5'),
    ));
    expect(find.text('VIEFLIX'), findsOneWidget);
    expect(find.text('NGƯỜI NHỆN'), findsOneWidget);
    expect(find.text('TẬP 5'), findsOneWidget);
  });

  testWidgets('phim lẻ (không có nhãn tập): chỉ hiện tên phim, không có dấu ·',
      (tester) async {
    await tester.pumpWidget(_wrap(const ChannelBug(movieName: 'Bố Già')));
    expect(find.text('BỐ GIÀ'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('tương phản đậm/nhạt: wordmark to + w700, tên phim nhỏ hơn + w500, '
      'số tập quay lại w700', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5'),
    ));
    final mark = tester.widget<Text>(find.text('VIEFLIX'));
    final name = tester.widget<Text>(find.text('NGƯỜI NHỆN'));
    final ep = tester.widget<Text>(find.text('TẬP 5'));

    expect(mark.style!.fontWeight, FontWeight.w700);
    expect(name.style!.fontWeight, FontWeight.w500);
    expect(ep.style!.fontWeight, FontWeight.w700);
    // Wordmark phải LỚN hơn dòng phim -> tạo bậc thị giác.
    expect(mark.style!.fontSize!, greaterThan(name.style!.fontSize!));
    // Wordmark giãn chữ rộng hơn hẳn (kiểu bảng chữ nhà đài).
    expect(mark.style!.letterSpacing!, greaterThan(name.style!.letterSpacing!));
  });

  testWidgets('tên phim dài: CẮT tên nhưng số tập vẫn hiện đủ', (tester) async {
    await tester.pumpWidget(_wrap(const ChannelBug(
      movieName: 'Vụ Án Bí Ẩn Ở Ngôi Làng Hẻo Lánh Phía Bắc Bán Đảo',
      episodeLabel: 'Tập 12',
    )));
    // Số tập KHÔNG được bị cắt mất — đây là thứ người xem cần nhất.
    expect(find.text('TẬP 12'), findsOneWidget);
    final name = tester.widget<Text>(
        find.text('VỤ ÁN BÍ ẨN Ở NGÔI LÀNG HẺO LÁNH PHÍA BẮC BÁN ĐẢO'));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull); // không vỡ layout
  });

  testWidgets('nằm im thì mờ, thanh điều khiển hiện thì sáng 100%', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5'),
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      ChannelBug.dimOpacity,
    );

    await tester.pumpWidget(_wrap(
      const ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5', bright: true),
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );
  });

  testWidgets('bấm vào chỗ logo thì XUYÊN xuống phim — góc logo không được thành '
      'vùng chết', (tester) async {
    var tappedVideo = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          // Đóng thế cho WebView đang chiếu phim ở dưới.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => tappedVideo = true,
              child: Container(color: Colors.black),
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5'),
          ),
        ]),
      ),
    ));

    await tester.tapAt(tester.getCenter(find.byType(ChannelBug)));
    await tester.pump();
    expect(tappedVideo, isTrue);
  });
}
