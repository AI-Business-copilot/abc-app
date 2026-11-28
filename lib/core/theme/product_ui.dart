import 'package:flutter/material.dart';

/// Ngôn ngữ thị giác của khối Hàng hóa / POS.
///
/// Toàn bộ mã màu được lấy mẫu pixel trực tiếp từ 2 ảnh thiết kế:
/// - `abc-app/sku.png`            (danh sách hàng hóa)
/// - `abc-app/thêm hàng hóa.png`  (thêm mới hàng hóa)
///
/// Không chỉnh màu theo cảm tính; nếu thiết kế đổi thì đo lại ảnh rồi sửa ở đây,
/// không sửa rải rác trong từng màn.
class ProductUi {
  // --- Bảng màu chung (sku.png) ---
  static const Color bg = Color(0xFFFAF8FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFF7EBE9);
  static const Color line = Color(0xFFF5E5E3);
  static const Color ink = Color(0xFF131B2E);
  static const Color sub = Color(0xFF5C403C);
  static const Color primary = Color(0xFFB70011);
  static const Color warn = Color(0xFF894900);
  static const Color danger = Color(0xFFBA1A1A);
  static const Color button = Color(0xFFDC2626);
  static const Color green = Color(0xFF006D30);
  static const Color outPillBg = Color(0xFFFFECEA);
  static const Color tile = Color(0xFFF2EFEF);

  // --- Bổ sung cho màn thêm hàng hóa (thêm hàng hóa.png) ---
  static const Color formBg = Color(0xFFF2F3FF);
  static const Color fieldBg = Color(0xFFF7F8FF);
  static const Color fieldBorder = Color(0xFFE2E7FF);
  static const Color softLine = Color(0xFFEAEDFF);
  static const Color roseTile = Color(0xFFF8EEF5);
  static const Color greenTile = Color(0xFFE7F5EA);
  static const Color peachTile = Color(0xFFFFDCC3);
  static const Color peachInk = Color(0xFF7A3D00);

  /// Nhãn trường nhập — đo trên mockup tối hơn `sub` một bậc.
  static const Color label = Color(0xFF3B3230);

  /// Font hiển thị: Playfair Display (đã nhúng, có dấu tiếng Việt).
  static const String font = 'PlayfairDisplay';

  static TextStyle t(
    double size,
    FontWeight weight,
    Color color, {
    double? spacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
      );
}
