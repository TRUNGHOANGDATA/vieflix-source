import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_xem_phim/player/channel_bug.dart';

/// Bọc widget trong khung tối giống lúc xem phim.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(backgroundColor: Colors.black, body: child),
    );

void main() {
  testWidgets('phim bộ: hiện "tên phim · tập"', (tester) async {
    await tester.pumpWidget(_wrap(
      const ChannelBug(movieName: 'Người Nhện', episodeLabel: 'Tập 5'),
    ));
    expect(find.text('Người Nhện · Tập 5'), findsOneWidget);
  });

  testWidgets('phim lẻ (không có nhãn tập): chỉ hiện tên phim, không có dấu ·',
      (tester) async {
    await tester.pumpWidget(_wrap(const ChannelBug(movieName: 'Bố Già')));
    expect(find.text('Bố Già'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('nằm im thì mờ 40%, thanh điều khiển hiện thì sáng 100%',
      (tester) async {
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

  testWidgets('tên phim dài bị cắt 1 dòng, không tràn ngang che cảnh',
      (tester) async {
    await tester.pumpWidget(_wrap(const ChannelBug(
      movieName: 'Vụ Án Bí Ẩn Ở Ngôi Làng Hẻo Lánh Phía Bắc Bán Đảo',
      episodeLabel: 'Tập 12',
    )));
    final t = tester.widget<Text>(find.byType(Text).last);
    expect(t.maxLines, 1);
    expect(t.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull); // không vỡ layout
  });
}
