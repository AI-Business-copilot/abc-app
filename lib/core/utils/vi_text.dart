/// Chuẩn hoá chữ tiếng Việt để so khớp tìm kiếm.
///
/// Mục đích: người dùng gõ "sua rua mat" vẫn tìm ra "Sữa Rửa Mặt", và gõ
/// "SỮA RỬA MẶT" cũng vậy. Không phụ thuộc bàn phím gõ ra NFC hay NFD.
///
/// File thuần Dart (không import Flutter) để test được bằng flutter_test.
library;

/// Mỗi nhóm: nguyên âm gốc -> toàn bộ biến thể có dấu của nó.
/// Gồm cả chính chữ gốc có dấu riêng (ă, â, ê, ô, ơ, ư) vì chúng cũng phải
/// quy về a, e, o, u khi tìm kiếm không dấu.
const Map<String, String> _vietGroups = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậ',
  'e': 'èéẻẽẹêềếểễệ',
  'i': 'ìíỉĩị',
  'o': 'òóỏõọôồốổỗộơờớởỡợ',
  'u': 'ùúủũụưừứửữự',
  'y': 'ỳýỷỹỵ',
  'd': 'đ',
};

/// Bảng tra dựng theo nhóm — không dựa vào thứ tự/độ dài nên không thể lệch.
final Map<String, String> _vietAccentMap = {
  for (final entry in _vietGroups.entries)
    for (var i = 0; i < entry.value.length; i++) entry.value[i]: entry.key,
};

/// Trả về chuỗi đã bỏ dấu, viết thường, cắt khoảng trắng hai đầu.
String normalizeForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final ch = lower[i];
    buffer.write(_vietAccentMap[ch] ?? ch);
  }
  return buffer.toString().trim();
}
