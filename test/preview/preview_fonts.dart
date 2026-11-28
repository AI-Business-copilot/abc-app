import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nạp font thật vào flutter_test để golden render đúng như trên máy.
///
/// Lưu ý: `testWidgets` chạy trong fake-async nên mọi I/O file phải bọc
/// `tester.runAsync`, nếu không Future sẽ không bao giờ hoàn tất (test treo).
Future<void> loadPreviewFonts() async {
  const weights = <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  final loader = FontLoader('PlayfairDisplay');
  for (final w in weights) {
    final file = File('assets/fonts/PlayfairDisplay-$w.ttf');
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  // MaterialIcons mặc định không có trong test -> icon sẽ ra ô vuông.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final icon = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!icon.existsSync()) return;
  final iconLoader = FontLoader('MaterialIcons');
  iconLoader.addFont(Future.value(ByteData.sublistView(await icon.readAsBytes())));
  await iconLoader.load();
}
