import 'package:flutter_test/flutter_test.dart';
import 'package:abc_app/features/invoices/models/invoice_models.dart';

void main() {
  group('Tra cứu hóa đơn - parse dữ liệu API', () {
    test('InvoiceOrder đọc đúng mã, tiền decimal và các dòng hàng', () {
      final order = InvoiceOrder.fromJson({
        'id': 'order-1',
        'orderCode': 'DH-2026-001',
        'status': 'COMPLETED',
        'createdAt': '2026-11-27T02:30:00.000Z',
        'totalGrossAmount': '1250000.00',
        'discountAmount': '50000.00',
        'totalNetAmount': '1200000.00',
        'grossProfit': '300000.00',
        'customer': {'id': 'c1', 'name': 'Nguyen Van A', 'phone': '0909123456'},
        'orderItems': [
          {
            'id': 'item-1',
            'quantity': 2,
            'unitPrice': '600000.00',
            'subtotal': '1200000.00',
            'discountAmount': '0.00',
            'variant': {
              'sku': 'SNK-RTR-41',
              'template': {'id': 'p1', 'name': 'Giay Sneaker'},
            },
            'lotItem': null,
          },
        ],
        'orderPayments': [
          {
            'id': 'pay-1',
            'paymentMethod': 'CASH',
            'amount': '1200000.00',
            'paymentReference': '',
            'createdAt': '2026-11-27T02:31:00.000Z',
          },
        ],
      });

      expect(order.code, 'DH-2026-001');
      expect(order.status, 'COMPLETED');
      expect(order.customerName, 'Nguyen Van A');
      expect(order.totalNetAmount, '1200000.00');
      expect(order.itemCount, 1);
      expect(order.items.first.sku, 'SNK-RTR-41');
      expect(order.items.first.productName, 'Giay Sneaker');
      expect(order.items.first.quantity, 2);
      expect(order.payments.first.method, 'CASH');
    });

    test('InvoicePage đọc phân trang và biết còn trang kế tiếp', () {
      final page = InvoicePage.fromJson({
        'items': [
          {
            'id': 'order-1',
            'orderCode': 'DH-001',
            'status': 'DRAFT',
            'totalNetAmount': '99000.00',
          },
        ],
        'pagination': {
          'page': 1,
          'pageSize': 20,
          'total': 25,
          'totalPages': 2,
        },
      });

      expect(page.items.length, 1);
      expect(page.total, 25);
      expect(page.hasMore, isTrue);
      expect(formatInvoiceMoney(page.items.first.totalNetAmount), '99.000 đ');
    });

    test('Dinh dang tien va ngay khong lam mat chuoi decimal', () {
      expect(formatInvoiceMoney('100000.00'), '100.000 đ');
      expect(formatInvoiceMoney('100000.50'), '100.000,50 đ');
      expect(formatInvoiceMoney('-2500'), '-2.500 đ');
      expect(formatInvoiceMoney(null), '—');

      expect(formatInvoiceDate('2026-11-27T02:30:00.000Z', withTime: false), isNotEmpty);
      expect(invoiceStatusLabel('COMPLETED'), 'Hoàn tất');
      expect(invoicePaymentLabel('BANK_TRANSFER'), 'Chuyển khoản');
    });
  });
}
