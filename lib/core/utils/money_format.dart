import 'package:intl/intl.dart';

/// Định dạng tiền từ chuỗi decimal của API mà không đưa qua double.
/// API của dự án trả tiền dạng "100000.00", không dùng float.
String formatDecimalMoney(Object? value) {
  if (value == null) return '—';
  final raw = value.toString().trim();
  if (raw.isEmpty) return '—';

  final negative = raw.startsWith('-');
  final unsigned = negative ? raw.substring(1) : raw;
  final parts = unsigned.split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final cents = parts.length > 1 ? parts[1].padRight(2, '0').substring(0, 2) : '00';
  final formatted = NumberFormat.decimalPattern('vi_VN').format(whole);
  final suffix = cents == '00' ? '' : ',$cents';
  return '${negative ? '-' : ''}$formatted$suffix đ';
}
