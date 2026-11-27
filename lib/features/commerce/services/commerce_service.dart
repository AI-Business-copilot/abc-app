import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/commerce_models.dart';

class CommerceService {
  CommerceService({Dio? dio}) : dio = dio ?? ApiClient().dio;
  final Dio dio;
  Future<Json> read(String path, [Json query = const {}]) async =>
      object((await dio.get(path, queryParameters: query)).data);
  Future<Json> write(
    String path, [
    Object? body,
    String method = 'POST',
  ]) async => object(
    (await dio.request(
      path,
      data: body ?? <String, dynamic>{},
      options: Options(method: method),
    )).data,
  );
  Future<CommercePage> page(String path, Json query) async =>
      CommercePage.fromJson(await read(path, query));
  Future<Json?> shift(String domain) async {
    final data = (await dio.get('/$domain/cash-shifts/current')).data;
    return data == null ? null : object(data);
  }

  Future<Json> openShift(String domain, String opening) => write(
    '/$domain/cash-shifts',
    {'openingCash': Money.parse(opening).toString()},
  );
  Future<Json> variants(String search, {String categoryId = ''}) => read(
    '/inventory/variants',
    {'search': search, 'categoryId': categoryId, 'limit': 100},
  );
  Future<Json> lots(String id) => read('/inventory/lots', {'variantId': id});
}

class PurchasesService extends CommerceService {
  PurchasesService({super.dio});
  Future<CommercePage> suppliers(Json query) =>
      page('/purchases/suppliers', query);
  Future<Json> saveSupplier(Json payload, {String? id}) => write(
    id == null ? '/purchases/suppliers' : '/purchases/suppliers/$id',
    payload,
    id == null ? 'POST' : 'PATCH',
  );
  Future<Json> lookupTax(String code) =>
      read('/purchases/suppliers/tax-lookup', {'taxCode': code});
  Future<CommercePage> products(String id, Json query) =>
      page('/purchases/suppliers/$id/products', query);
  Future<Json> saveProduct(String id, Json payload) =>
      write('/purchases/suppliers/$id/products', payload, 'PUT');
  Future<Json> retireProduct(String id, String variantId) =>
      write('/purchases/suppliers/$id/products/$variantId', null, 'DELETE');
  Future<Json> importProducts(
    String id,
    String filename,
    Uint8List bytes, {
    Json? mapping,
    String? digest,
  }) => write(
    '/purchases/suppliers/$id/products/import/${digest == null ? 'preview' : 'confirm'}',
    FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (mapping != null) 'mapping': jsonEncode(mapping),
      'digest': ?digest,
    }),
  );
  Future<Json> reconciliation(String id) =>
      read('/purchases/suppliers/$id/debt-reconciliation');
  Future<Json> applyReconciliation(Json preview) => write(
    '/purchases/suppliers/${preview['supplierId']}/debt-reconciliation',
    {'apply': true, 'expectedDebtAmount': preview['storedDebtAmount']},
  );
  Future<CommercePage> orders(Json query) => page('/purchases/orders', query);
  Future<Json> order(String id) => read('/purchases/orders/$id');
  Future<Json> saveOrder(Json payload, {String? id}) => write(
    id == null ? '/purchases/orders' : '/purchases/orders/$id',
    payload,
    id == null ? 'POST' : 'PATCH',
  );
  Future<Json> orderAction(String id, String action) {
    if (!['confirm', 'cancel', 'close'].contains(action)) {
      throw ArgumentError.value(action);
    }
    return write('/purchases/orders/$id/$action');
  }

  Future<Json> receive(String id, Json payload) =>
      write('/purchases/orders/$id/receipts', payload);
  Future<Json> previewReceipt(String id, Json payload) =>
      write('/purchases/orders/$id/receipt-drafts', payload);
  Future<Json> confirmReceipt(String id, String token) => write(
    '/purchases/orders/$id/receipt-drafts/confirm',
    {'draftToken': token},
  );
  Future<CommercePage> receipts(Json query) =>
      page('/purchases/receipts', query);
  Future<Json> receipt(String id) => read('/purchases/receipts/$id');
  Future<Json> pay(String id, String cumulativeTotal) => write(
    '/purchases/receipts/$id/payment',
    {'paidAmount': cumulativeTotal},
    'PATCH',
  );
  Future<Json> payments(String id) => read('/purchases/receipts/$id/payments');
  Future<Json> correct(Json receipt, List<Json> items) => write(
    '/purchases/receipts/${receipt['id']}/items',
    {'expectedTotalAmount': receipt['totalAmount'], 'items': items},
    'PATCH',
  );
}

class SalesService extends CommerceService {
  SalesService({super.dio});
  Future<CommercePage> orders(Json query) => page('/sales/orders', query);
  Future<Json> order(String id) => read('/sales/orders/$id');
  Future<Json> create(Json payload) => write('/sales/orders', payload);
  Future<Json> preview(List<Json> items) =>
      write('/sales/orders/promotion-preview', {'items': items});
  Future<Json> pay(
    Json order, {
    required String method,
    String reference = '',
  }) => write('/sales/orders/${order['id']}/payments', {
    'confirmed': true,
    'paymentMethod': method,
    'amount': order['totalNetAmount'],
    if (reference.trim().isNotEmpty) 'paymentReference': reference.trim(),
  });
  Future<Json> cancel(String id) => write('/sales/orders/$id/cancel');
  Future<CommercePage> customers(Json query) => page('/sales/customers', query);
  Future<Json> createCustomer(String name, String phone) =>
      write('/sales/customers', {'name': name.trim(), 'phone': phone.trim()});
}
