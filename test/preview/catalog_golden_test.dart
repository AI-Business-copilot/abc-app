import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/screens/product_catalog_tab.dart';

/// Render màn "Danh Sách Hàng Hóa" bằng đúng engine Flutter + font Playfair
/// để so 1:1 với abc-app/sku.png (487x1183 px, máy ~406dp -> chia 1,2).
Future<void> _loadFonts() async {
  const weights = <String>[
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ];
  final loader = FontLoader('PlayfairDisplay');
  for (final w in weights) {
    final file = File('assets/fonts/PlayfairDisplay-$w.ttf');
    // ignore: avoid_print
    print('font: ${file.path} exists=${file.existsSync()}');
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  // ignore: avoid_print
  print('fonts loaded');

  // Nạp luôn MaterialIcons để golden hiện đúng icon (test mặc định không có).
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icon = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    // ignore: avoid_print
    print('icons: ${icon.path} exists=${icon.existsSync()}');
    if (icon.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(Future.value(ByteData.sublistView(await icon.readAsBytes())));
      await iconLoader.load();
    }
  }
}

ProductItem _p({
  required String name,
  required String code,
  required String sku,
  required int stock,
  required double price,
  String unit = 'chai',
  String? category,
}) {
  return ProductItem(
    id: code,
    code: code,
    name: name,
    categoryName: category,
    totalStock: stock,
    retailValue: stock * price,
    avgPrice: price,
    unitOfMeasure: unit,
    variants: [
      ProductVariant(
        id: '$code-v1',
        sku: sku,
        title: 'Mặc định',
        basePrice: price,
        costPrice: price * 0.6,
        totalOnHand: stock,
      ),
    ],
  );
}

void main() {
  testWidgets('preview danh sách hàng hóa', (tester) async {
    // testWidgets chạy trong fake-async: I/O thật phải bọc runAsync,
    // nếu không Future của File.readAsBytes sẽ không bao giờ hoàn tất.
    await tester.runAsync(_loadFonts);

    await tester.binding.setSurfaceSize(const Size(406, 986));
    tester.view.devicePixelRatio = 1.0;

    final products = [
      _p(
        name: 'Serum Dưỡng Ẩm B5 Concentrate',
        code: 'SRM-B5',
        sku: 'SRM-B5-30ML-STD',
        stock: 85,
        price: 280000,
        category: 'Chăm sóc da',
      ),
      _p(
        name: 'Kem Dưỡng Trắng Da Vitamin C',
        code: 'CRM-VC',
        sku: 'CRM-VC-50G-STD',
        stock: 48,
        price: 320000,
        category: 'Chăm sóc da',
      ),
      _p(
        name: 'Giày Sneaker Runner Pro',
        code: 'SNK-RTR',
        sku: 'SNK-RTR-BRW-41',
        stock: 0,
        price: 1250000,
        unit: 'đôi',
        category: 'Giày dép',
      ),
      _p(
        name: 'Nước Hoa Hồng Rose Toner',
        code: 'TNR-RSE',
        sku: 'TNR-RSE-150ML',
        stock: 3,
        price: 195000,
        category: 'Chăm sóc da',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ProductCatalogTab(initialProducts: products),
      ),
    );
    // ignore: avoid_print
    print('pumped');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('settled');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/catalog.png'),
    );
    // ignore: avoid_print
    print('golden written');
  });
}
