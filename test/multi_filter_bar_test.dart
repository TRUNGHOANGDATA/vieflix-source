import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_xem_phim/data/movie_source.dart';
import 'package:app_xem_phim/widgets/multi_filter_bar.dart';

void main() {
  testWidgets('bấm "Thể loại" -> danh sách thả xuống, chọn một mục là lọc + đóng', (tester) async {
    var current = const BrowseFilter(country: 'han-quoc');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => MultiFilterBar(
            current: current,
            onChanged: (f) => setState(() => current = f),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Thể loại'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả thể loại'), findsOneWidget);

    await tester.tap(find.text('Hành Động'));
    await tester.pumpAndSettle();
    expect(current.genre, 'hanh-dong');
    expect(current.country, 'han-quoc'); // chiều khác giữ nguyên
    expect(find.text('Tất cả thể loại'), findsNothing); // danh sách đã đóng
    expect(find.text('Hành Động'), findsOneWidget); // nút ghi mục đã chọn
  });
}
