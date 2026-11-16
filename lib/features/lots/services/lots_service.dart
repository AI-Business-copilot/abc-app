import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/lots/models/lot_models.dart';

/// Thin Dio wrapper around the F08 lot endpoints.
class LotsService {
  final _dio = ApiClient().dio;

  /// `GET /inventory/lots/expiring` — flat list of lot items.
  Future<ExpiringLotsResult> getExpiringLots({
    LotStatus? status,
    int skip = 0,
    int take = 50,
  }) async {
    final response = await _dio.get(
      '/inventory/lots/expiring',
      queryParameters: {
        if (status != null) 'status': status.code,
        'skip': skip,
        'take': take,
      },
    );
    return ExpiringLotsResult.fromJson(
      (response.data as Map<String, dynamic>?) ?? const {},
    );
  }

  /// `GET /inventory/lots/expiring?groupBy=lot` — one row per batch.
  Future<ExpiringLotsResult> getExpiringBatches({
    LotStatus? status,
    int skip = 0,
    int take = 50,
  }) async {
    final response = await _dio.get(
      '/inventory/lots/expiring',
      queryParameters: {
        if (status != null) 'status': status.code,
        'groupBy': 'lot',
        'skip': skip,
        'take': take,
      },
    );
    return ExpiringLotsResult.fromJson(
      (response.data as Map<String, dynamic>?) ?? const {},
    );
  }

  /// `GET /inventory/lots/:id` — one batch with its variant items.
  Future<LotBatch> getLot(String lotId) async {
    final response = await _dio.get('/inventory/lots/$lotId');
    return LotBatch.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }

  /// `POST /inventory/lots/:lotId/items/:itemId/quarantine` — pulls a quantity off the shelf.
  Future<void> quarantineLot(
    String lotId,
    String lotItemId, {
    required int quantity,
    String? note,
  }) async {
    await _dio.post(
      '/inventory/lots/$lotId/items/$lotItemId/quarantine',
      data: {
        'quantity': quantity,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }
}
