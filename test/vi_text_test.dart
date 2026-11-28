import 'package:flutter_test/flutter_test.dart';
import 'package:abc_app/core/utils/vi_text.dart';

void main() {
  group('normalizeForSearch', () {
    test('bỏ dấu nguyên âm, giữ nguyên phụ âm', () {
      expect(normalizeForSearch('Sữa Rửa Mặt'), 'sua rua mat');
    });

    test('đ/Đ chuyển thành d', () {
      expect(normalizeForSearch('Đường Đen'), 'duong den');
      expect(normalizeForSearch('đôi dép'), 'doi dep');
    });

    test('chữ hoa có dấu', () {
      expect(normalizeForSearch('SỮA RỬA MẶT'), 'sua rua mat');
      expect(normalizeForSearch('BÔNG TẨY TRANG'), 'bong tay trang');
    });

    test('phủ đủ các nhóm ă â ê ô ơ ư', () {
      expect(normalizeForSearch('Khăn Ướt'), 'khan uot');
      expect(normalizeForSearch('Bàn Chải Ô'), 'ban chai o');
      expect(normalizeForSearch('Nước Tẩy Trang'), 'nuoc tay trang');
      expect(normalizeForSearch('Ớt Chuông'), 'ot chuong');
    });

    test('chuỗi ASCII giữ nguyên, cắt khoảng trắng hai đầu', () {
      expect(normalizeForSearch('  SKU-LIP-VLV-RUBY-01  '), 'sku-lip-vlv-ruby-01');
    });

    test('gõ không dấu khớp tên có dấu', () {
      final ten = normalizeForSearch('Serum Dưỡng Ẩm B5 Concentrate');
      expect(ten.contains(normalizeForSearch('duong am')), isTrue);
      expect(ten.contains(normalizeForSearch('DUONG AM')), isTrue);
    });
  });
}
