typedef Json = Map<String, dynamic>;

Json object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Json> records(Object? value) =>
    value is List ? value.map(object).toList() : <Json>[];
String textOf(Object? value) => value?.toString() ?? '';
String dayOf(Object? value) => textOf(value).split('T').first;
String shopToday([DateTime? now]) => (now ?? DateTime.now())
    .toUtc()
    .add(const Duration(hours: 7))
    .toIso8601String()
    .substring(0, 10);
String documentCode(String prefix) =>
    '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}';

/// Decimal money stays exact on native and web, including receipt totals.
class Money implements Comparable<Money> {
  Money._(this.cents);
  final BigInt cents;
  factory Money.parse(Object? value, {int wholeDigits = 10}) {
    final input = textOf(value);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input)) {
      throw const FormatException(
        'Số tiền phải không âm, tối đa 2 chữ số thập phân (ví dụ 12500.50).',
      );
    }
    final parts = input.split('.');
    final cents =
        BigInt.parse(parts[0]) * BigInt.from(100) +
        BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(2, '0'));
    if (cents >= BigInt.from(10).pow(wholeDigits + 2)) {
      throw const FormatException('Số tiền vượt giới hạn cho phép.');
    }
    return Money._(cents);
  }
  static final zero = Money._(BigInt.zero);
  Money operator +(Money other) => Money._(cents + other.cents);
  Money operator -(Money other) => Money._(cents - other.cents);
  Money times(int quantity) => Money._(cents * BigInt.from(quantity));
  bool get isZero => cents == BigInt.zero;
  @override
  int compareTo(Money other) => cents.compareTo(other.cents);
  @override
  String toString() {
    final absolute = cents.abs();
    return '${cents.isNegative ? '-' : ''}${absolute ~/ BigInt.from(100)}.${(absolute % BigInt.from(100)).toString().padLeft(2, '0')}';
  }
}

int quantityOf(String value, {bool allowZero = false}) {
  final quantity = int.tryParse(value);
  if (!RegExp(r'^\d+$').hasMatch(value) ||
      quantity == null ||
      quantity < (allowZero ? 0 : 1) ||
      quantity > 2147483647) {
    throw const FormatException(
      'Số lượng phải là số nguyên từ 1 đến 2147483647.',
    );
  }
  return quantity;
}

String paymentTotal(String previous, String additional, String total) {
  final amount = Money.parse(additional);
  final next = Money.parse(previous, wholeDigits: 12) + amount;
  if (amount.isZero ||
      next.compareTo(Money.parse(total, wholeDigits: 12)) > 0) {
    throw const FormatException(
      'Số tiền trả thêm phải lớn hơn 0 và không vượt công nợ còn lại.',
    );
  }
  return next.toString();
}

class CommercePage {
  CommercePage.fromJson(Json json)
    : items = records(json['items']),
      page = (object(json['pagination'])['page'] as num?)?.toInt() ?? 1,
      totalPages =
          (object(json['pagination'])['totalPages'] as num?)?.toInt() ?? 1,
      total = (object(json['pagination'])['total'] as num?)?.toInt() ?? 0;
  final List<Json> items;
  final int page, totalPages, total;
}

class ReceiveLine {
  ReceiveLine({
    required this.poItemId,
    required this.qty,
    required this.price,
    this.lot = '',
    this.expiration = '',
    this.manufacturing = '',
  });
  final String poItemId, qty, price, lot, expiration, manufacturing;
}

Json buildReceiptPayload(
  Json order,
  String code,
  String paid,
  List<ReceiveLine> lines,
) {
  if (code.trim().isEmpty || code.trim().length > 50) {
    throw const FormatException('Mã phiếu nhận cần từ 1 đến 50 ký tự.');
  }
  final counts = <String, int>{};
  final selected = <Json>[];
  var total = Money.zero;
  for (final line in lines) {
    final qty = quantityOf(line.qty, allowZero: true);
    if (qty == 0) continue;
    final candidates = records(
      order['purchaseOrderItems'],
    ).where((item) => item['id'] == line.poItemId);
    if (candidates.isEmpty) {
      throw const FormatException('Dòng nhận không thuộc đơn mua.');
    }
    final item = candidates.first;
    final count = (counts[line.poItemId] ?? 0) + qty;
    counts[line.poItemId] = count;
    if (count > (item['remainingQty'] as num).toInt()) {
      throw const FormatException('Tổng số nhận vượt phần còn thiếu của SKU.');
    }
    final price = Money.parse(line.price);
    total = total + price.times(qty);
    final tracked =
        object(object(item['variant'])['template'])['hasLotTracking'] == true;
    if (tracked && (line.lot.trim().isEmpty || line.expiration.isEmpty)) {
      throw const FormatException('Hàng theo lô cần số lô và hạn sử dụng.');
    }
    if (tracked) {
      validateDay(line.expiration);
      if (line.expiration.compareTo(shopToday()) < 0) {
        throw const FormatException('Không nhận lô đã hết hạn.');
      }
      if (line.manufacturing.isNotEmpty) {
        validateDay(line.manufacturing);
        if (line.manufacturing.compareTo(line.expiration) > 0) {
          throw const FormatException(
            'Ngày sản xuất phải trước hoặc bằng hạn sử dụng.',
          );
        }
      }
    }
    selected.add({
      'poItemId': line.poItemId,
      'receivedQty': qty,
      'actualCost': price.toString(),
      if (tracked) ...{
        'lotNumber': line.lot.trim(),
        'expirationDate': line.expiration,
        if (line.manufacturing.isNotEmpty)
          'manufacturingDate': line.manufacturing,
      },
    });
  }
  if (selected.isEmpty || selected.length > 500) {
    throw const FormatException(
      'Phiếu nhận cần từ 1 đến 500 dòng có số lượng lớn hơn 0.',
    );
  }
  Money.parse(total.toString(), wholeDigits: 12);
  final payment = Money.parse(paid);
  if (payment.compareTo(total) > 0) {
    throw const FormatException('Tiền trả ngay vượt tiền hàng thực nhận.');
  }
  return {
    'receiptCode': code.trim(),
    'paidAmount': payment.toString(),
    'items': selected,
  };
}

void validateDay(String day) {
  final parsed = DateTime.tryParse(day);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != day) {
    throw const FormatException('Ngày phải hợp lệ theo dạng YYYY-MM-DD.');
  }
}

String variantLabel(Json line) {
  final variant = object(line['variant']);
  return '${variant['sku'] ?? line['sku'] ?? ''} · ${object(variant['template'])['name'] ?? line['productName'] ?? ''}';
}
