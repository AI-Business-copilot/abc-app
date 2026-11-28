import 'package:flutter_test/flutter_test.dart';
import 'package:abc_app/features/purchases/models/purchase_models.dart';

void main() {
  group('Đặt hàng NCC - parse dữ liệu API', () {
    test('Supplier đọc đúng mã, tên và công nợ', () {
      final supplier = Supplier.fromJson({
        'id': 'sup-1',
        'supplierCode': 'NCC001',
        'name': 'Công ty TNHH Minh Khang',
        'contactPerson': 'Nguyen Thi B',
        'phone': '0909123456',
        'email': 'contact@minhkhang.vn',
        'address': 'TP.HCM',
        'debtAmount': '15000000.00',
        'isActive': true,
      });

      expect(supplier.code, 'NCC001');
      expect(supplier.displayName, 'NCC001 • Công ty TNHH Minh Khang');
      expect(supplier.debtAmount, '15000000.00');
      expect(supplier.isActive, isTrue);
    });

    test('SupplierProduct lấy cấu hình min/bội số từ catalog', () {
      final product = SupplierProduct.fromJson({
        'id': 'var-1',
        'sku': 'ASM-TRANG-L',
        'productName': 'Áo sơ mi Oxford',
        'unitOfMeasure': 'cái',
        'supplyPrice': '185000.00',
        'onHand': 0,
        'hasLotTracking': false,
        'catalog': {
          'supplierSku': 'MK-OXF-L',
          'supplierProductName': 'Áo Oxford trắng size L',
          'minOrderQty': 12,
          'orderMultiple': 6,
          'leadTimeDays': 5,
          'supplyPrice': '185000.00',
        },
      });

      expect(product.variantId, 'var-1');
      expect(product.displayName, 'Áo Oxford trắng size L');
      expect(product.minOrderQty, 12);
      expect(product.orderMultiple, 6);
      expect(product.leadTimeDays, 5);
      expect(isValidOrderQty(11, 12, 6), isFalse);
      expect(isValidOrderQty(12, 12, 6), isTrue);
      expect(isValidOrderQty(18, 12, 6), isTrue);
      expect(isValidOrderQty(15, 12, 6), isFalse);
    });

    test('PurchaseOrder đọc dòng hàng, remainingQty và totals', () {
      final order = PurchaseOrder.fromJson({
        'id': 'po-1',
        'poCode': 'PO-20261128-A1B2',
        'status': 'PARTIALLY_RECEIVED',
        'supplierId': 'sup-1',
        'supplier': {'id': 'sup-1', 'name': 'Minh Khang', 'phone': '0909123456'},
        'orderDate': '2026-11-28T00:00:00.000Z',
        'expectedDeliveryDate': '2026-12-03T00:00:00.000Z',
        'purchaseOrderItems': [
          {
            'id': 'item-1',
            'variantId': 'var-1',
            'sku': 'ASM-TRANG-L',
            'orderedQty': 24,
            'receivedQty': 6,
            'remainingQty': 18,
            'unitPrice': '185000.00',
            'subtotal': '4440000.00',
            'variant': {
              'sku': 'ASM-TRANG-L',
              'template': {'name': 'Áo sơ mi Oxford', 'unitOfMeasure': 'cái'},
            },
          },
        ],
        'totals': {
          'orderedQty': 24,
          'receivedQty': 6,
          'orderedAmount': '4440000.00',
          'receivedAmount': '1110000.00',
          'paidAmount': '0.00',
          'debtAmount': '1110000.00',
        },
      });

      expect(order.code, 'PO-20261128-A1B2');
      expect(order.status, 'PARTIALLY_RECEIVED');
      expect(order.supplierName, 'Minh Khang');
      expect(order.itemCount, 1);
      expect(order.items.first.remainingQty, 18);
      expect(order.totals.orderedAmount, '4440000.00');
      expect(purchaseStatusLabel(order.status), 'Nhận một phần');
    });

    test('PurchaseOrderPage phân trang', () {
      final page = PurchaseOrderPage.fromJson({
        'items': [
          {
            'id': 'po-1',
            'poCode': 'PO-001',
            'status': 'ORDERED',
            'purchaseOrderItems': [],
          },
        ],
        'pagination': {
          'page': 1,
          'pageSize': 20,
          'total': 21,
          'totalPages': 2,
        },
      });

      expect(page.items.length, 1);
      expect(page.hasMore, isTrue);
    });

    test('Sinh mã PO và preview tiền', () {
      final code = generatePurchaseCode(DateTime(2026, 11, 28));
      expect(code, startsWith('PO-20261128-'));
      expect(code.length, 16);
      expect(previewPurchaseAmount('185000.00', 12), '2.220.000 đ');
    });
  });
}
