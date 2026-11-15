import 'package:flutter_test/flutter_test.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/alerts/models/alert_models.dart';

void main() {
  group('Mobile Models Parsing Tests', () {
    test('ProductItem and ProductVariant parse correctly from JSON', () {
      final json = {
        'id': 'prod_123',
        'name': 'Áo sơ mi Oxford',
        'categoryPath': 'Thời trang > Nam',
        'stockQty': 25,
        'retailValue': 7500000,
        'avgPrice': 300000,
        'variants': [
          {
            'id': 'var_1',
            'sku': 'ASM-TRANG-L',
            'barcode': '8931234567890',
            'title': 'Trắng / L',
            'basePrice': 300000,
            'costPrice': 180000,
            'inventoryBalances': [
              {'quantityOnHand': 15},
              {'quantityOnHand': 10},
            ],
          }
        ],
      };

      final product = ProductItem.fromJson(json);
      expect(product.id, 'prod_123');
      expect(product.name, 'Áo sơ mi Oxford');
      expect(product.totalStock, 25);
      expect(product.variants.length, 1);

      final variant = product.variants.first;
      expect(variant.sku, 'ASM-TRANG-L');
      expect(variant.barcode, '8931234567890');
      expect(variant.totalOnHand, 25);
      expect(variant.basePrice, 300000);
    });

    test('LotAlertItem parses correctly from JSON', () {
      final json = {
        'lotCode': 'LOT-2026-05',
        'productName': 'Kem chống nắng SPF50',
        'variantTitle': 'Tuýp 50ml',
        'expirationDate': '2026-11-20',
        'daysLeft': 6,
        'status': 'WARNING',
        'currentQuantity': 12,
      };

      final lotAlert = LotAlertItem.fromJson(json);
      expect(lotAlert.lotCode, 'LOT-2026-05');
      expect(lotAlert.productName, 'Kem chống nắng SPF50');
      expect(lotAlert.daysLeft, 6);
      expect(lotAlert.status, 'WARNING');
      expect(lotAlert.currentQuantity, 12);
    });
  });
}
