import 'dart:io';

import 'package:dio/dio.dart';
import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/scrap/models/scrap_models.dart';

/// Creates a scrap order with its evidence photos.
///
/// The endpoint is `multipart/form-data`: the photos go into the `files` field and the
/// order fields are sent as text parts. The `Content-Type: application/json` base header
/// of [ApiClient] must not reach this request, otherwise Dio would not add the multipart
/// boundary and the server would reject the body.
class ScrapUploadService {
  final _dio = ApiClient().dio;

  Future<ScrapOrder> createScrapOrder({
    String? lotItemId,
    String? variantId,
    required String scrapReason,
    required int scrapQty,
    ScrapSource? scrapSource,
    required List<File> images,
  }) async {
    assert(lotItemId != null || variantId != null,
        'A scrap order needs either a lot item or a variant.');
    final form = FormData();
    if (lotItemId != null) {
      form.fields.add(MapEntry('lotItemId', lotItemId));
    }
    if (variantId != null) {
      form.fields.add(MapEntry('variantId', variantId));
    }
    form.fields.add(MapEntry('scrapReason', scrapReason.trim()));
    form.fields.add(MapEntry('scrapQty', scrapQty.toString()));
    if (scrapSource != null) {
      form.fields.add(MapEntry('scrapSource', scrapSource.code));
    }
    for (final file in images) {
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(file.path),
        ),
      );
    }

    final response = await _dio.post(
      '/inventory/scrap-orders',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    return ScrapOrder.fromJson((response.data as Map<String, dynamic>?) ?? const {});
  }
}
