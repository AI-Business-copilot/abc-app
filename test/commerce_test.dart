import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abc_app/core/network/api_error.dart';
import 'package:abc_app/features/auth/services/auth_service.dart';
import 'package:abc_app/features/commerce/models/commerce_models.dart';
import 'package:abc_app/features/commerce/services/commerce_service.dart';
import 'package:abc_app/features/commerce/widgets/commerce_widgets.dart';
import 'package:abc_app/features/purchases/screens/purchase_order_screens.dart';
import 'package:abc_app/features/sales/screens/sale_detail_screen.dart';
import 'package:abc_app/features/sales/screens/sale_editor_screen.dart';
import 'package:abc_app/features/sales/screens/sale_receipt.dart';

const permissions = [
  'inventory.read',
  'inventory.receive',
  'finance.read',
  'orders.read',
  'orders.create',
  'inventory.adjust',
];
Json purchaseOrder({bool tracked = false}) => {
  'id': 'po-1',
  'poCode': 'PO-1',
  'purchaseOrderItems': [
    {
      'id': 'line-1',
      'variantId': 'v1',
      'remainingQty': 5,
      'orderedQty': 5,
      'receivedQty': 0,
      'unitPrice': '0.10',
      'variant': {
        'sku': 'SKU-1',
        'template': {'name': 'Tea', 'hasLotTracking': tracked},
      },
    },
  ],
};
Json saleOrder({
  String status = 'DRAFT',
  String total = '150000.00',
  String cashier = 'user-1',
}) => {
  'id': 'sale-1',
  'orderCode': 'POS-1',
  'cashierId': cashier,
  'shiftId': 'shift-1',
  'status': status,
  'createdAt': '2026-11-23T05:00:00Z',
  'totalGrossAmount': '150000.00',
  'discountAmount': total == '0.00' ? '150000.00' : '0.00',
  'totalNetAmount': total,
  'customer': null,
  'orderItems': [
    {
      'id': 'item-1',
      'variantId': 'v1',
      'quantity': 3,
      'unitPrice': '50000.00',
      'discountAmount': '0.00',
      'subtotal': '150000.00',
      'variant': {
        'sku': 'SKU-1',
        'template': {'name': 'Tea'},
      },
    },
  ],
  'orderPayments': [],
  'inventoryLedger': [],
};

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Json result = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) await requestStream.drain<void>();
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeSales extends SalesService {
  FakeSales({Json? initial})
    : current = initial ?? saleOrder(),
      super(dio: Dio());
  Json current;
  int payCalls = 0, createCalls = 0;
  bool disconnect = false;
  Completer<void>? pendingPayment;
  String? method, reference;
  Json? paidSnapshot;
  Json? createdPayload;
  @override
  Future<Json> variants(String search, {String categoryId = ''}) async => {
    'total': 1,
    'categories': [],
    'items': [
      {
        'id': 'v1',
        'sku': 'SKU-1',
        'productName': 'Tea',
        'basePrice': 50000,
        'onHand': 10,
        'hasLotTracking': false,
      },
    ],
  };
  @override
  Future<Json> preview(List<Json> items) async => {
    'totalGrossAmount': '50000.00',
    'discountAmount': '0.00',
    'totalNetAmount': '50000.00',
    'promotion': null,
  };
  @override
  Future<Json> create(Json payload) async {
    createCalls++;
    createdPayload = payload;
    return current;
  }

  @override
  Future<Json> order(String id) async => Map<String, dynamic>.from(current);
  @override
  Future<Json?> shift(String domain) async => {
    'id': 'shift-1',
    'status': 'OPEN',
    'openedAt': '2026-11-23T01:00:00Z',
    'openingCash': '0.00',
  };
  @override
  Future<Json> pay(
    Json order, {
    required String method,
    String reference = '',
  }) async {
    payCalls++;
    this.method = method;
    this.reference = reference;
    paidSnapshot = {...order};
    if (pendingPayment != null) await pendingPayment!.future;
    if (disconnect) {
      throw DioException(
        requestOptions: RequestOptions(path: '/sales/orders/sale-1/payments'),
        type: DioExceptionType.connectionError,
      );
    }
    current = {...current, 'status': 'COMPLETED'};
    return current;
  }
}

class FakePurchases extends PurchasesService {
  FakePurchases() : super(dio: Dio());
  @override
  Future<Json?> shift(String domain) async => null;
  @override
  Future<Json> previewReceipt(String id, Json payload) async => {
    'draftToken': 'signed-token',
    'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    'totalAmount': '0.30',
    'debtAmount': '0.30',
    'receipt': payload,
  };
  int confirmCalls = 0;
  @override
  Future<Json> confirmReceipt(String id, String token) async {
    confirmCalls++;
    throw DioException(
      requestOptions: RequestOptions(
        path: '/purchases/orders/$id/receipt-drafts/confirm',
      ),
      type: DioExceptionType.connectionError,
    );
  }
}

Future<void> session({List<String> grants = permissions}) async {
  SharedPreferences.setMockInitialValues({});
  await AuthService.saveActiveBusiness(
    'business-1',
    'Shop',
    role: 'OWNER',
    userId: 'user-1',
    permissions: grants,
  );
}

Future<void> showScreen(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Exact money and F03 receipt validation', () {
    test('keeps cents exact for fractional and large receipt totals', () {
      expect((Money.parse('0.10') + Money.parse('0.20')).toString(), '0.30');
      expect(
        Money.parse('999999999999.99', wholeDigits: 12).toString(),
        '999999999999.99',
      );
      expect(Money.parse('0.10').times(3).toString(), '0.30');
      expect(
        (Money.parse('200000') - Money.parse('150000.01')).toString(),
        '49999.99',
      );
    });
    test('rejects invalid money and per-transaction overflow', () {
      for (final invalid in [
        '-1',
        '1e3',
        '1.001',
        'NaN',
        '',
        '1,000',
        '10000000000',
      ]) {
        expect(
          () => Money.parse(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    });
    test('quantities are bounded positive integers', () {
      for (final invalid in ['0', '-1', '1.5', '1e2', '2147483648', '']) {
        expect(() => quantityOf(invalid), throwsFormatException);
      }
      expect(quantityOf('0', allowZero: true), 0);
      expect(quantityOf('2147483647'), 2147483647);
    });
    test(
      'adds supplier installment to cumulative paid amount without rounding',
      () {
        expect(paymentTotal('0.10', '0.20', '0.30'), '0.30');
        expect(() => paymentTotal('10', '0', '20'), throwsFormatException);
        expect(() => paymentTotal('10', '11', '20'), throwsFormatException);
        expect(
          () => paymentTotal('0', '10000000000', '999999999999'),
          throwsFormatException,
        );
      },
    );
    test('partial receipt skips zero rows and preserves server item IDs', () {
      final payload = buildReceiptPayload(purchaseOrder(), ' PR-1 ', '0.10', [
        ReceiveLine(poItemId: 'line-1', qty: '3', price: '0.10'),
        ReceiveLine(poItemId: 'line-1', qty: '0', price: '0.10'),
      ]);
      expect(payload, {
        'receiptCode': 'PR-1',
        'paidAmount': '0.10',
        'items': [
          {'poItemId': 'line-1', 'receivedQty': 3, 'actualCost': '0.10'},
        ],
      });
    });
    test(
      'split lots aggregate quantities before checking remaining amount',
      () {
        final future = '2099-01-01';
        final a = ReceiveLine(
          poItemId: 'line-1',
          qty: '3',
          price: '0.10',
          lot: 'A',
          expiration: future,
        );
        final b = ReceiveLine(
          poItemId: 'line-1',
          qty: '2',
          price: '0.10',
          lot: 'B',
          expiration: future,
        );
        expect(
          records(
            buildReceiptPayload(purchaseOrder(tracked: true), 'PR', '0.50', [
              a,
              b,
            ])['items'],
          ).length,
          2,
        );
        expect(
          () => buildReceiptPayload(purchaseOrder(tracked: true), 'PR', '0', [
            a,
            a,
          ]),
          throwsFormatException,
        );
      },
    );
    test('rejects overpayment, empty receipts and foreign PO lines', () {
      final row = ReceiveLine(poItemId: 'line-1', qty: '3', price: '0.10');
      expect(
        () => buildReceiptPayload(purchaseOrder(), 'PR', '0.31', [row]),
        throwsFormatException,
      );
      expect(
        () => buildReceiptPayload(purchaseOrder(), 'PR', '0', []),
        throwsFormatException,
      );
      expect(
        () => buildReceiptPayload(purchaseOrder(), 'PR', '0', [
          ReceiveLine(poItemId: 'other', qty: '1', price: '1'),
        ]),
        throwsFormatException,
      );
    });
    test('tracked products require lot and valid unexpired dates', () {
      for (final row in [
        ReceiveLine(poItemId: 'line-1', qty: '1', price: '1'),
        ReceiveLine(
          poItemId: 'line-1',
          qty: '1',
          price: '1',
          lot: 'A',
          expiration: '2099-02-30',
        ),
        ReceiveLine(
          poItemId: 'line-1',
          qty: '1',
          price: '1',
          lot: 'A',
          expiration: '2020-01-01',
        ),
        ReceiveLine(
          poItemId: 'line-1',
          qty: '1',
          price: '1',
          lot: 'A',
          expiration: '2099-01-01',
          manufacturing: '2099-01-02',
        ),
      ]) {
        expect(
          () => buildReceiptPayload(purchaseOrder(tracked: true), 'PR', '0', [
            row,
          ]),
          throwsFormatException,
        );
      }
    });
    test('store day follows Vietnam at UTC date boundary', () {
      expect(shopToday(DateTime.parse('2026-11-22T18:00:00Z')), '2026-11-23');
      expect(shopToday(DateTime.parse('2026-11-22T16:59:00Z')), '2026-11-22');
    });
    test('surfaces the error field returned by the Express backend', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/sales/orders'),
        response: Response(
          requestOptions: RequestOptions(path: '/sales/orders'),
          statusCode: 409,
          data: {'error': 'Insufficient sellable stock.'},
        ),
      );
      expect(apiErrorMessage(error), 'Insufficient sellable stock.');
    });
  });

  group('Backend API contracts', () {
    late RecordingAdapter adapter;
    late PurchasesService purchases;
    late SalesService sales;
    setUp(() {
      adapter = RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
        ..httpClientAdapter = adapter;
      purchases = PurchasesService(dio: dio);
      sales = SalesService(dio: dio);
    });
    test('supplier catalog uses PUT and retirement uses DELETE', () async {
      await purchases.saveProduct('s1', {
        'variantId': 'v1',
        'supplyPrice': '12.50',
        'minOrderQty': 2,
        'orderMultiple': 2,
        'isPreferred': true,
      });
      expect(adapter.requests.last.method, 'PUT');
      expect(
        adapter.requests.last.uri.path,
        '/api/purchases/suppliers/s1/products',
      );
      await purchases.retireProduct('s1', 'v1');
      expect(adapter.requests.last.method, 'DELETE');
      expect(
        adapter.requests.last.uri.path,
        '/api/purchases/suppliers/s1/products/v1',
      );
    });
    test(
      'receipt confirmation sends signed token with no edited amounts',
      () async {
        await purchases.confirmReceipt('p1', 'signed-token');
        expect(
          adapter.requests.single.uri.path,
          '/api/purchases/orders/p1/receipt-drafts/confirm',
        );
        expect(adapter.requests.single.data, {'draftToken': 'signed-token'});
      },
    );
    test(
      'payment sends cumulative amount while correction includes expected snapshot',
      () async {
        await purchases.pay('r1', '150.10');
        expect(adapter.requests.last.method, 'PATCH');
        expect(adapter.requests.last.data, {'paidAmount': '150.10'});
        final changes = [
          {
            'id': 'i1',
            'receivedQty': 2,
            'actualCost': '3',
            'expectedReceivedQty': 3,
            'expectedActualCost': '4',
          },
        ];
        await purchases.correct({'id': 'r1', 'totalAmount': '12'}, changes);
        expect(adapter.requests.last.data, {
          'expectedTotalAmount': '12',
          'items': changes,
        });
      },
    );
    test('reconciliation guards the stored debt seen in preview', () async {
      await purchases.applyReconciliation({
        'supplierId': 's1',
        'storedDebtAmount': '-5.00',
        'calculatedDebtAmount': '10.00',
      });
      expect(adapter.requests.single.data, {
        'apply': true,
        'expectedDebtAmount': '-5.00',
      });
    });
    test('order lifecycle rejects unsupported actions locally', () async {
      expect(() => purchases.orderAction('p1', 'delete'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
      await purchases.orderAction('p1', 'confirm');
      expect(
        adapter.requests.last.uri.path,
        '/api/purchases/orders/p1/confirm',
      );
    });
    test(
      'imports upload identical file with mapping and preview digest',
      () async {
        final bytes = Uint8List.fromList(utf8.encode('SKU,Price\nA,10'));
        await purchases.importProducts(
          's1',
          'catalog.csv',
          bytes,
          mapping: {'sku': 0, 'price': 1},
          digest: 'digest-123',
        );
        final req = adapter.requests.single, form = req.data as FormData;
        expect(
          req.uri.path,
          '/api/purchases/suppliers/s1/products/import/confirm',
        );
        expect(form.files.single.value.filename, 'catalog.csv');
        expect(form.files.single.value.length, bytes.length);
        expect(Map.fromEntries(form.fields), {
          'mapping': '{"sku":0,"price":1}',
          'digest': 'digest-123',
        });
      },
    );
    test(
      'sale payment uses server total, confirmation and optional bank reference',
      () async {
        await sales.pay(saleOrder(total: '0.00'), method: 'CASH');
        expect(adapter.requests.last.data, {
          'confirmed': true,
          'paymentMethod': 'CASH',
          'amount': '0.00',
        });
        await sales.pay(
          saleOrder(),
          method: 'BANK_TRANSFER',
          reference: ' FT-001 ',
        );
        expect(adapter.requests.last.data, {
          'confirmed': true,
          'paymentMethod': 'BANK_TRANSFER',
          'amount': '150000.00',
          'paymentReference': 'FT-001',
        });
      },
    );
    test('list queries preserve server pagination and filters', () async {
      adapter.result = {
        'items': [],
        'pagination': {'page': 3, 'totalPages': 7, 'total': 123},
      };
      final result = await purchases.orders({
        'page': 3,
        'supplierId': 's1',
        'status': 'ORDERED',
        'from': '2026-11-01',
      });
      expect(result.page, 3);
      expect(result.totalPages, 7);
      expect(result.total, 123);
      expect(adapter.requests.single.queryParameters['supplierId'], 's1');
    });
  });

  group('Receipt preferences', () {
    test(
      'automatic receipt is claimed before printing and only once per business/order',
      () async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 'b1',
          SaleReceipt.automaticKey: true,
        });
        expect(await SaleReceipt.claimAutomatic('receipt-unique'), isTrue);
        expect(await SaleReceipt.claimAutomatic('receipt-unique'), isFalse);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_business_id', 'b2');
        expect(await SaleReceipt.claimAutomatic('receipt-unique'), isTrue);
      },
    );
    test(
      'printing is opt-in and incomplete orders cannot be printed',
      () async {
        SharedPreferences.setMockInitialValues({});
        expect(await SaleReceipt.claimAutomatic('not-enabled'), isFalse);
        await expectLater(
          SaleReceipt.build(saleOrder(), 80),
          throwsFormatException,
        );
      },
    );
  });

  group('Mobile workflows', () {
    setUp(() => session());
    testWidgets(
      'cart creates a recoverable draft and shows a changed server total before collecting money',
      (tester) async {
        final api = FakeSales();
        await showScreen(tester, SaleEditorScreen(api: api));
        await tapVisible(tester, find.text('Chọn sản phẩm'));
        await tapVisible(tester, find.text('SKU-1 · Tea'));
        await tapVisible(tester, find.text('Kiểm tra giá & khuyến mãi'));
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Tạo đơn & tiếp tục thanh toán'),
        );
        expect(api.createCalls, 1);
        expect(api.createdPayload!['items'], [
          {'variantId': 'v1', 'quantity': 1},
        ]);
        expect(api.createdPayload!['shiftId'], 'shift-1');
        expect(api.payCalls, 0);
        expect(
          find.text(
            'Giá hoặc khuyến mãi đã thay đổi. Kiểm tra tổng mới trước khi thu tiền.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'editing cart quantities invalidates the previous promotion preview',
      (tester) async {
        final api = FakeSales();
        await showScreen(tester, SaleEditorScreen(api: api));
        await tapVisible(tester, find.text('Chọn sản phẩm'));
        await tapVisible(tester, find.text('SKU-1 · Tea'));
        await tapVisible(tester, find.text('Kiểm tra giá & khuyến mãi'));
        final create = find.widgetWithText(
          FilledButton,
          'Tạo đơn & tiếp tục thanh toán',
        );
        await tester.scrollUntilVisible(
          create,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<FilledButton>(create).onPressed, isNotNull);
        final qty = find.widgetWithText(TextFormField, 'Số lượng *');
        await tester.scrollUntilVisible(
          qty,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(qty, '2');
        await tester.pump();
        await tester.scrollUntilVisible(
          create,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<FilledButton>(create).onPressed, isNull);
      },
    );
    testWidgets(
      'payment button is disabled while the first request is in flight',
      (tester) async {
        final pending = Completer<void>();
        final api = FakeSales()..pendingPayment = pending;
        await showScreen(tester, SaleDetailScreen(api: api, id: 'sale-1'));
        await tester.enterText(find.byType(TextFormField).first, '150000');
        await tapVisible(tester, find.byType(CheckboxListTile));
        final pay = find.widgetWithText(
          FilledButton,
          'Xác nhận thanh toán & xuất kho',
        );
        await tester.ensureVisible(pay);
        await tester.pumpAndSettle();
        await tester.tap(pay);
        await tester.pump();
        expect(api.payCalls, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Đang xử lý…'),
              )
              .onPressed,
          isNull,
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(api.payCalls, 1);
      },
    );
    testWidgets(
      'cash checkout requires tender and explicit confirmation; sends total only',
      (tester) async {
        final api = FakeSales();
        await showScreen(tester, SaleDetailScreen(api: api, id: 'sale-1'));
        final pay = find.widgetWithText(
          FilledButton,
          'Xác nhận thanh toán & xuất kho',
        );
        expect(tester.widget<FilledButton>(pay).onPressed, isNull);
        await tester.enterText(find.byType(TextFormField).first, '200000');
        await tester.pump();
        expect(find.text('50.000 đ'), findsOneWidget);
        await tapVisible(tester, find.byType(CheckboxListTile));
        await tapVisible(tester, pay);
        expect(api.payCalls, 1);
        expect(api.method, 'CASH');
        expect(api.paidSnapshot!['totalNetAmount'], '150000.00');
        expect(
          find.text('Đã ghi nhận thanh toán và xuất kho.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('bank payment needs confirmation and includes reference', (
      tester,
    ) async {
      final api = FakeSales();
      await showScreen(tester, SaleDetailScreen(api: api, id: 'sale-1'));
      await tapVisible(tester, find.text('Chuyển khoản').first);
      await tester.enterText(find.byType(TextFormField).first, 'FT-001');
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Xác nhận thanh toán & xuất kho'),
      );
      expect(api.method, 'BANK_TRANSFER');
      expect(api.reference, 'FT-001');
      expect(api.payCalls, 1);
    });
    testWidgets('free order completes without cash tender input', (
      tester,
    ) async {
      final api = FakeSales(initial: saleOrder(total: '0.00'));
      await showScreen(tester, SaleDetailScreen(api: api, id: 'sale-1'));
      expect(find.byType(TextFormField), findsNothing);
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Hoàn tất & xuất kho'),
      );
      expect(api.payCalls, 1);
      expect(api.paidSnapshot!['totalNetAmount'], '0.00');
    });
    testWidgets(
      'uncertain payment blocks repeat until order status is reloaded',
      (tester) async {
        final api = FakeSales()..disconnect = true;
        await showScreen(tester, SaleDetailScreen(api: api, id: 'sale-1'));
        await tester.enterText(find.byType(TextFormField).first, '150000');
        await tapVisible(tester, find.byType(CheckboxListTile));
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Xác nhận thanh toán & xuất kho'),
        );
        expect(api.payCalls, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(
                  FilledButton,
                  'Xác nhận thanh toán & xuất kho',
                ),
              )
              .onPressed,
          isNull,
        );
        // The server committed despite the lost response. Reload must reveal COMPLETED without resubmitting.
        api.current = saleOrder(status: 'COMPLETED');
        await tapVisible(tester, find.text('Tải lại trạng thái đơn'));
        expect(
          find.text('Đã ghi nhận thanh toán và xuất kho.'),
          findsOneWidget,
        );
        expect(api.payCalls, 1);
      },
    );
    testWidgets('another cashier cannot pay or cancel a draft', (tester) async {
      await showScreen(
        tester,
        SaleDetailScreen(
          api: FakeSales(initial: saleOrder(cashier: 'other')),
          id: 'sale-1',
        ),
      );
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận thanh toán & xuất kho'),
        findsNothing,
      );
      expect(find.text('Hủy đơn nháp'), findsNothing);
    });
    testWidgets('uncertain receipt confirmation cannot be submitted twice', (
      tester,
    ) async {
      final api = FakePurchases();
      await showScreen(
        tester,
        ReceiveOrderScreen(api: api, order: purchaseOrder()),
      );
      final qty = find.widgetWithText(
        TextFormField,
        'Số thực nhận (0 nếu chưa giao)',
      );
      await tester.scrollUntilVisible(
        qty,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(qty, '3');
      await tapVisible(tester, find.text('Xem trước phiếu nhận'));
      await tapVisible(tester, find.text('Xác nhận nhập kho & thanh toán'));
      expect(api.confirmCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Xác nhận nhập kho & thanh toán',
              ),
            )
            .onPressed,
        isNull,
      );
    });
    testWidgets('SKU picker fixed query filters survive list defaults', (
      tester,
    ) async {
      final queries = <Json>[];
      await showScreen(
        tester,
        RecordPicker(
          title: 'Suppliers',
          extra: const {'isActive': 'true'},
          label: (v) => '',
          load: (query) async {
            queries.add(query);
            return CommercePage.fromJson({
              'items': [],
              'pagination': {'page': 1, 'totalPages': 0, 'total': 0},
            });
          },
        ),
      );
      expect(queries.single['isActive'], 'true');
      expect(tester.takeException(), isNull);
    });
    testWidgets('sale editor denies users without inventory access', (
      tester,
    ) async {
      await session(grants: ['orders.read', 'orders.create']);
      await showScreen(tester, SaleEditorScreen(api: FakeSales()));
      expect(
        find.text('Tạo đơn tại quầy cần quyền tạo đơn và xem kho.'),
        findsOneWidget,
      );
    });
  });
}
