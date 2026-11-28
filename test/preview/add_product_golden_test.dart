import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:abc_app/features/products/models/category_attribute_model.dart';
import 'package:abc_app/features/products/screens/add_product_screen.dart';

import 'preview_fonts.dart';

/// Render màn "Thêm Mới Hàng Hóa" để đối chiếu bố cục với
/// `abc-app/thêm hàng hóa.png` (617x2850 px -> máy ~406dp).
void main() {
  testWidgets('preview thêm hàng hóa', (tester) async {
    await tester.runAsync(loadPreviewFonts);

    await tester.binding.setSurfaceSize(const Size(406, 900));
    tester.view.devicePixelRatio = 1.0;

    final categories = [
      CategoryItem(id: 'c1', name: 'Chăm sóc da'),
      CategoryItem(id: 'c2', name: 'Trang điểm'),
      CategoryItem(id: 'c3', name: 'Nước hoa'),
    ];
    final attributes = [
      AttributeItem(
        id: 'a1',
        name: 'Dung tích',
        values: [
          AttributeValueItem(id: 'v1', value: '30ml'),
          AttributeValueItem(id: 'v2', value: '60ml'),
        ],
      ),
      AttributeItem(
        id: 'a2',
        name: 'Phiên bản',
        values: [AttributeValueItem(id: 'v3', value: 'Tiêu Chuẩn')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AddProductScreen(
          previewCategories: categories,
          previewAttributes: attributes,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_product_top.png'),
    );

    final pageList = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
    await tester.drag(pageList, const Offset(0, -760));
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_product_bottom.png'),
    );
  });
}
