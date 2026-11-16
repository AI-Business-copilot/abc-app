import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';

/// Thin Dio wrapper around the F08 scrap order endpoints (JSON only).
/// The multipart create call lives in `scrap_upload_service.dart`.
class ScrapService {
  final _dio = ApiClient().dio;

  /// `GET /inventory/scrap-orders`
  Future<({List<ScrapOrder> orders, int total})> listScrapOrders({
    ScrapStatus? status,
    int skip = 0,
    int take = 50,
  }) async {
    final response = await _dio.get(
      '/inventory/scrap-orders',
      queryParameters: {
        if (status != null) 'status': status.code,
        'skip': skip,
        'take': take,
      },
    );
    final data = (response.data as Map<String, dynamic>?) ?? const {};
    final orders = (data['orders'] as List?) ?? const [];
    return (
      orders: orders
          .whereType<Map<String, dynamic>>()
          .map(ScrapOrder.fromJson)
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// `GET /inventory/scrap-orders/:id` — the order with its signed evidence photos.
  Future<ScrapOrderDetail> getScrapOrder(String id) async {
    final response = await _dio.get('/inventory/scrap-orders/$id');
    return ScrapOrderDetail.fromJson(
      (response.data as Map<String, dynamic>?) ?? const {},
    );
  }

  /// `GET /inventory/scrap-orders/:id/images` — the photos alone, with 5-minute signed URLs.
  Future<List<ScrapImage>> listScrapImages(String id) async {
    final response = await _dio.get('/inventory/scrap-orders/$id/images');
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ScrapImage.fromJson)
          .toList();
    }
    return const [];
  }

  /// `PATCH /inventory/scrap-orders/:id` — only the creator can change a pending order.
  Future<ScrapOrder> updateScrapOrder(
    String id, {
    int? scrapQty,
    String? scrapReason,
  }) async {
    final response = await _dio.patch(
      '/inventory/scrap-orders/$id',
      data: {
        'scrapQty': ?scrapQty,
        'scrapReason': ?scrapReason?.trim(),
      },
    );
    return ScrapOrder.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `DELETE /inventory/scrap-orders/:id` — only the creator can delete a pending order.
  Future<void> deleteScrapOrder(String id) async {
    await _dio.delete('/inventory/scrap-orders/$id');
  }

  /// `PATCH /inventory/scrap-orders/:id/approve` — owner only.
  /// The ids must match the photos currently on the order, otherwise the server answers 409.
  Future<ApproveScrapResult> approveScrapOrder(String id, List<String> reviewedImageIds) async {
    final response = await _dio.patch(
      '/inventory/scrap-orders/$id/approve',
      data: {'reviewedImageIds': reviewedImageIds},
    );
    return ApproveScrapResult.fromJson(
      (response.data as Map<String, dynamic>?) ?? const {},
    );
  }

  /// `PATCH /inventory/scrap-orders/:id/reject` — owner only.
  Future<ScrapOrder> rejectScrapOrder(
    String id, {
    required RejectionReasonCode reasonCode,
    String? note,
  }) async {
    final response = await _dio.patch(
      '/inventory/scrap-orders/$id/reject',
      data: {
        'reasonCode': reasonCode.code,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return ScrapOrder.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `PATCH /inventory/scrap-orders/:id/cancel` — owner only, closes without a decision.
  Future<ScrapOrder> cancelScrapOrder(String id, {String? note}) async {
    final response = await _dio.patch(
      '/inventory/scrap-orders/$id/cancel',
      data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
    );
    return ScrapOrder.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `GET /inventory/scrap-statistics`
  Future<ScrapStatistics> getStatistics() async {
    final response = await _dio.get('/inventory/scrap-statistics');
    return ScrapStatistics.fromJson(
      (response.data as Map<String, dynamic>?) ?? const {},
    );
  }
}
