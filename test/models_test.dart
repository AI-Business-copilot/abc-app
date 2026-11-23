import 'package:flutter_test/flutter_test.dart';
import 'package:abc_app/core/config/app_config.dart';
import 'package:abc_app/core/utils/image_url.dart';
import 'package:abc_app/features/audits/models/audit_models.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';

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
  });

  group('F07 — Audit models', () {
    test('StockAudit parses the header and its items', () {
      final json = {
        'id': 'audit_1',
        'auditCode': 'PK-2026-001',
        'status': 'IN_PROGRESS',
        'isLockedForAudit': true,
        'countStartAt': '2026-11-15T08:00:00.000Z',
        'createdBy': {'id': 'u1', 'name': 'Chủ cửa hàng'},
        'itemCount': 2,
        'items': [
          {
            'id': 'item_1',
            'variantId': 'var_1',
            'sku': 'ASM-TRANG-L',
            'productName': 'Áo sơ mi Oxford',
            'attributeText': 'Trắng / L',
            'lotItemId': 'lot_item_1',
            'lotNumber': 'LOT-2026-05',
            'snapshotQty': 10,
            'countedQty': 8,
            'diffQty': -2,
            'discrepancyReason': 'Hai cái bị mất',
            'itemStatus': 'PENDING_APPROVAL',
            'assignedTo': {'id': 'u2', 'name': 'Nhân viên'},
          },
        ],
      };

      final audit = StockAudit.fromJson(json);
      expect(audit.id, 'audit_1');
      expect(audit.auditCode, 'PK-2026-001');
      expect(audit.status, AuditStatus.inProgress);
      expect(audit.isLockedForAudit, isTrue);
      expect(audit.itemCount, 2);
      expect(audit.createdBy?.name, 'Chủ cửa hàng');
      expect(audit.items.length, 1);

      final item = audit.items.first;
      expect(item.sku, 'ASM-TRANG-L');
      expect(item.productName, 'Áo sơ mi Oxford');
      expect(item.snapshotQty, 10);
      expect(item.countedQty, 8);
      expect(item.diffQty, -2);
      expect(item.computedDiff, -2);
      expect(item.discrepancyReason, 'Hai cái bị mất');
      expect(item.itemStatus, AuditItemStatus.pendingApproval);
      expect(item.assignedTo?.name, 'Nhân viên');
    });

    test('ApproveItemResult reports the auto-apply flag', () {
      final result = ApproveItemResult.fromJson({
        'id': 'item_1',
        'itemStatus': 'APPROVED',
        'approvedAt': '2026-11-15T10:00:00.000Z',
        'auditAutoApplied': true,
      });

      expect(result.itemStatus, AuditItemStatus.approved);
      expect(result.auditAutoApplied, isTrue);
      expect(result.approvedAt, isNotNull);
    });

    test('StaffMember filters out owners and inactive members', () {
      final active = StaffMember.fromJson({
        'role': 'STAFF',
        'status': 'ACTIVE',
        'user': {'id': 'u2', 'fullName': 'Nhân viên', 'email': 'a@b.c'},
      });
      final owner = StaffMember.fromJson({
        'role': 'OWNER',
        'status': 'ACTIVE',
        'user': {'id': 'u1', 'fullName': 'Chủ', 'email': 'o@b.c'},
      });

      expect(active.isAssignable, isTrue);
      expect(active.fullName, 'Nhân viên');
      expect(owner.isAssignable, isFalse);
    });

    test('VariantLot is blocked when it already has a scrap order', () {
      final lot = VariantLot.fromJson({
        'id': 'lot_item_1',
        'lotId': 'lot_1',
        'lotNumber': 'LOT-2026-05',
        'quantityOnHand': 5,
        'hasOpenScrapOrder': true,
        'isScrapped': false,
      });

      expect(lot.onHand, 5);
      expect(lot.isBlocked, isTrue);
    });

    test('AuditProductOption parses the product list payload', () {
      final product = AuditProductOption.fromJson({
        'id': 'tpl_1',
        'name': 'Áo thun nam',
        'imageUrl': 'https://cdn.example.com/a.png',
        'hasLotTracking': true,
        'skus': [
          {'id': 'v1', 'sku': 'AT-1'},
          {'id': 'v2', 'sku': 'AT-2'},
        ],
      });

      expect(product.id, 'tpl_1');
      expect(product.name, 'Áo thun nam');
      expect(product.imageUrl, 'https://cdn.example.com/a.png');
      expect(product.skuCount, 2);
      expect(product.hasLotTracking, isTrue);
    });

    test('AuditProductOption falls back to variantCount when skus is missing', () {
      final product = AuditProductOption.fromJson({
        'id': 'tpl_2',
        'name': 'Cà phê hạt',
        'variantCount': 4,
        'hasLotTracking': false,
      });

      expect(product.skuCount, 4);
      expect(product.hasLotTracking, isFalse);
      expect(product.imageUrl, isNull);
    });

    test('VariantOption.fromTemplateJson joins attributes and sums balances', () {
      final variant = VariantOption.fromTemplateJson({
        'id': 'var_1',
        'sku': 'AT-DO-L',
        'barcode': '893001',
        'isActive': true,
        'variantAttributeValues': [
          {
            'attribute': {'name': 'Màu'},
            'attributeValue': {'value': 'Đỏ'},
          },
          {
            'attribute': {'name': 'Size'},
            'attributeValue': {'value': 'L'},
          },
        ],
        'inventoryBalances': [
          {'quantityOnHand': 7},
          {'quantityOnHand': 3},
        ],
      }, 'Áo thun nam');

      expect(variant.id, 'var_1');
      expect(variant.sku, 'AT-DO-L');
      expect(variant.productName, 'Áo thun nam');
      expect(variant.attributeText, 'Đỏ · L');
      expect(variant.onHand, 10);
    });

    test('VariantOption.fromTemplateJson tolerates missing attributes and balances', () {
      final variant = VariantOption.fromTemplateJson({
        'id': 'var_2',
        'sku': 'AT-XL',
      }, 'Áo thun nam');

      expect(variant.attributeText, '');
      expect(variant.onHand, 0);
      expect(variant.barcode, '');
    });
  });

  group('F07 — Image url helper', () {
    test('primaryImageUrl returns the first url of a JSON array', () {
      expect(
        primaryImageUrl('["https://cdn.example.com/1.png", "https://cdn.example.com/2.png"]'),
        'https://cdn.example.com/1.png',
      );
    });

    test('primaryImageUrl returns a plain url as is', () {
      expect(primaryImageUrl(' https://cdn.example.com/a.png '), 'https://cdn.example.com/a.png');
    });

    test('primaryImageUrl returns null for empty or invalid input', () {
      expect(primaryImageUrl(null), isNull);
      expect(primaryImageUrl(''), isNull);
      expect(primaryImageUrl('   '), isNull);
      expect(primaryImageUrl('[]'), isNull);
    });
  });

  group('F08 — Lot models', () {
    test('LotItem parses the expiry payload', () {
      final json = {
        'id': 'lot_item_1',
        'lotId': 'lot_1',
        'variantId': 'var_1',
        'lotNumber': 'LOT-2026-05',
        'expirationDate': '2026-11-20T00:00:00.000Z',
        'dbStatus': 'ACTIVE',
        'calculatedStatus': 'WARNING',
        'effectiveStatus': 'WARNING',
        'daysUntilExpiry': 6,
        'onHand': 12,
        'damaged': 2,
        'variant': {
          'id': 'var_1',
          'sku': 'KCN-TUYP-50',
          'template': {'name': 'Kem chống nắng SPF50'},
        },
      };

      final lot = LotItem.fromJson(json);
      expect(lot.id, 'lot_item_1');
      expect(lot.lotNumber, 'LOT-2026-05');
      expect(lot.effectiveStatus, LotStatus.warning);
      expect(lot.daysUntilExpiry, 6);
      expect(lot.onHand, 12);
      expect(lot.damaged, 2);
      expect(lot.totalStock, 14);
      expect(lot.variant.sku, 'KCN-TUYP-50');
      expect(lot.variant.productName, 'Kem chống nắng SPF50');
      expect(lot.expirationDate, isNotNull);
    });

    test('ExpiringLotsResult parses lots, total and summary', () {
      final result = ExpiringLotsResult.fromJson({
        'total': 3,
        'summary': {'healthy': 1, 'warning': 2, 'unusable': 0, 'quarantined': 0, 'scrapped': 0, 'total': 3},
        'lots': [
          {
            'id': 'lot_item_1',
            'lotNumber': 'LOT-A',
            'effectiveStatus': 'WARNING',
            'daysUntilExpiry': 5,
            'onHand': 3,
            'damaged': 0,
            'variant': {'id': 'v1', 'sku': 'A', 'template': {'name': 'A'}},
          },
          {
            'id': 'lot_item_2',
            'lotNumber': 'LOT-B',
            'effectiveStatus': 'UNUSABLE',
            'daysUntilExpiry': -2,
            'onHand': 1,
            'damaged': 0,
            'variant': {'id': 'v2', 'sku': 'B', 'template': {'name': 'B'}},
          },
        ],
      });

      expect(result.total, 3);
      expect(result.lots.length, 2);
      expect(result.summary.warning, 2);
      expect(result.summary.countOf(LotStatus.unusable), 0);
      expect(result.lots.first.effectiveStatus, LotStatus.warning);
      expect(result.lots.last.daysUntilExpiry, -2);
    });

    test('ExpiringLotsResult parses the grouped batch shape', () {
      final result = ExpiringLotsResult.fromJson({
        'total': 1,
        'lots': [
          {
            'id': 'lot_1',
            'lotNumber': 'LOT-X',
            'items': [
              {
                'id': 'lot_item_1',
                'lotNumber': 'LOT-X',
                'effectiveStatus': 'QUARANTINED',
                'daysUntilExpiry': 0,
                'onHand': 2,
                'damaged': 0,
                'variant': {'id': 'v1', 'sku': 'X', 'template': {'name': 'X'}},
              },
            ],
          },
        ],
      });

      expect(result.batches.length, 1);
      expect(result.batches.first.items.first.effectiveStatus, LotStatus.quarantined);
    });
  });

  group('F08 — Scrap models', () {
    test('ScrapOrder parses the order payload', () {
      final json = {
        'id': 'scrap_1',
        'scrapCode': 'HH-2026-001',
        'variantId': 'var_1',
        'lotItemId': 'lot_item_1',
        'scrapQty': 3,
        'unitCost': 18000.0,
        'scrapSource': 'DAMAGED_STOCK',
        'scrapReason': 'Vỡ hộp',
        'status': 'PENDING',
        'createdBy': 'u2',
        'createdAt': '2026-11-15T08:30:00.000Z',
        'variant': {'id': 'var_1', 'sku': 'KCN-TUYP-50', 'template': {'name': 'Kem SPF50'}},
        'lotItem': {'id': 'lot_item_1', 'status': 'QUARANTINED', 'lot': {'lotNumber': 'LOT-2026-05'}},
        'createdByUser': {'id': 'u2', 'fullName': 'Nhân viên', 'email': 'a@b.c'},
        '_count': {
          'images': {'count': 2},
        },
      };

      final order = ScrapOrder.fromJson(json);
      expect(order.scrapCode, 'HH-2026-001');
      expect(order.scrapQty, 3);
      expect(order.scrapSource, ScrapSource.damagedStock);
      expect(order.status, ScrapStatus.pending);
      expect(order.variant.sku, 'KCN-TUYP-50');
      expect(order.variant.productName, 'Kem SPF50');
      expect(order.lotItem?.lotNumber, 'LOT-2026-05');
      expect(order.createdByUser?.fullName, 'Nhân viên');
      expect(order.imageCount, 2);
      expect(order.estimatedLoss, 54000.0);
    });

    test('ScrapOrderDetail carries the evidence photos', () {
      final detail = ScrapOrderDetail.fromJson({
        'id': 'scrap_1',
        'scrapCode': 'HH-2026-001',
        'variantId': 'var_1',
        'scrapQty': 1,
        'unitCost': 1000.0,
        'scrapSource': 'SELLABLE_STOCK',
        'scrapReason': 'Hết hạn',
        'status': 'PENDING',
        'createdBy': 'u2',
        'variant': {'id': 'var_1', 'sku': 'A', 'template': {'name': 'A'}},
        'images': [
          {
            'id': 'img_1',
            'scrapOrderId': 'scrap_1',
            'mimeType': 'image/jpeg',
            'sizeBytes': 1024,
            'uploadedBy': 'u2',
            'uploadedByName': 'Nhân viên',
          },
        ],
      });

      expect(detail.images.length, 1);
      expect(detail.images.first.id, 'img_1');
      expect(detail.images.first.mimeType, 'image/jpeg');
      expect(detail.scrapSource, ScrapSource.sellableStock);
    });

    test('RejectionReasonCode maps the backend codes', () {
      expect(RejectionReasonCode.fromCode('WRONG_QUANTITY'), RejectionReasonCode.wrongQuantity);
      expect(RejectionReasonCode.fromCode('PHOTO_UNCLEAR'), RejectionReasonCode.photoUnclear);
      expect(RejectionReasonCode.fromCode('NOT_REMOVED_FROM_SHELF'), RejectionReasonCode.notRemovedFromShelf);
      expect(RejectionReasonCode.fromCode('OTHER'), RejectionReasonCode.other);
      expect(RejectionReasonCode.fromCode('NOPE'), isNull);
      expect(RejectionReasonCode.wrongQuantity.label, isNotEmpty);
    });

    test('ScrapStatistics parses the counts and the by-source split', () {
      final stats = ScrapStatistics.fromJson({
        'pendingCount': 2,
        'completedCount': 5,
        'rejectedCount': 1,
        'cancelledCount': 0,
        'totalLossValue': 120000.0,
        'bySource': {'DAMAGED_STOCK': 4, 'SELLABLE_STOCK': 1},
      });

      expect(stats.pendingCount, 2);
      expect(stats.completedCount, 5);
      expect(stats.totalLossValue, 120000.0);
      expect(stats.damagedStockCount, 4);
      expect(stats.sellableStockCount, 1);
    });
  });

  group('OAuth Redirect URL', () {
    test('native uses the custom scheme registered in the platform configs', () {
      expect(AppConfig.appUrlScheme, 'io.supabase.abcapps');
      expect(AppConfig.appOAuthRedirectUrl, 'io.supabase.abcapps://login-callback');
    });

    test('oauthRedirectUrl has no query string', () {
      final redirect = AppConfig.oauthRedirectUrl;
      final parsed = Uri.parse(redirect);
      expect(parsed.query, isEmpty);
      expect(parsed.fragment, isEmpty);
    });
  });
}
