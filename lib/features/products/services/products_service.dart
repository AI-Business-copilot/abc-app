import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/products/models/product_model.dart';
import 'package:abc_app/features/products/models/category_attribute_model.dart';

class ProductsService {
  final _dio = ApiClient().dio;

  Future<List<ProductItem>> getProducts({String? keyword, String? categoryId}) async {
    final response = await _dio.get(
      '/products/list',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty) 'q': keyword.trim(),
        if (categoryId != null && categoryId.trim().isNotEmpty) 'categoryId': categoryId.trim(),
        'pageSize': 50,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final list = (data['items'] ?? data['data']) as List?;
      if (list != null) {
        return list
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<void> updateProductTemplate(String id, {
    String? name,
    String? description,
    String? imageUrl,
    String? categoryId,
  }) async {
    await _dio.patch(
      '/products/templates/$id',
      data: {
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl.trim(),
        if (categoryId != null) 'categoryId': categoryId.trim(),
      },
    );
  }

  Future<List<CategoryItem>> getCategories() async {
    final response = await _dio.get('/categories');
    final data = response.data;
    if (data is List) {
      return data.map((c) => CategoryItem.fromJson(c)).toList();
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List).map((c) => CategoryItem.fromJson(c)).toList();
    }
    return [];
  }

  Future<CategoryItem> createCategory({required String name, String? parentId}) async {
    final response = await _dio.post(
      '/categories',
      data: {
        'name': name.trim(),
        if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
      },
    );
    final data = response.data is Map<String, dynamic> && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return CategoryItem.fromJson(data);
  }

  Future<List<AttributeItem>> getAttributes() async {
    final response = await _dio.get('/products/attributes');    final data = response.data;
    if (data is List) {
      return data.map((a) => AttributeItem.fromJson(a)).toList();
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List).map((a) => AttributeItem.fromJson(a)).toList();
    }
    return [];
  }

  Future<AttributeItem> createAttribute({required String name}) async {
    final response = await _dio.post(
      '/products/attributes',
      data: {'name': name.trim()},
    );
    final data = response.data is Map<String, dynamic> && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return AttributeItem.fromJson(data);
  }

  Future<void> addAttributeValue({required String attributeId, required String value}) async {
    await _dio.post(
      '/products/attributes/values',
      data: {
        'attributeId': attributeId,
        'value': value.trim(),
      },
    );
  }

  /// Tạo mẫu hàng hóa (POST /products/templates).
  /// Tiền gửi dạng chuỗi decimal theo quy ước API của dự án.
  Future<Map<String, dynamic>> createTemplate({
    required String name,
    String? code,
    String? categoryId,
    String? unitOfMeasure,
    bool hasLotTracking = false,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final response = await _dio.post(
      '/products/templates',
      data: {
        'name': name.trim(),
        if (code != null && code.trim().isNotEmpty) 'code': code.trim().toUpperCase(),
        if (categoryId != null && categoryId.trim().isNotEmpty) 'categoryId': categoryId.trim(),
        if (unitOfMeasure != null && unitOfMeasure.trim().isNotEmpty)
          'unitOfMeasure': unitOfMeasure.trim(),
        'hasLotTracking': hasLotTracking,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
        'isActive': isActive,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      return inner is Map<String, dynamic> ? inner : data;
    }
    return <String, dynamic>{};
  }

  /// Sinh biến thể từ thuộc tính (POST /products/templates/:id/variants/generate).
  Future<List<Map<String, dynamic>>> generateVariants(
    String templateId, {
    List<Map<String, dynamic>> attributes = const [],
    String? basePrice,
    String? costPrice,
  }) async {
    final response = await _dio.post(
      '/products/templates/$templateId/variants/generate',
      data: {
        'attributes': attributes,
        'defaults': {
          'basePrice': ?basePrice,
          'costPrice': ?costPrice,
        },
        'barcodeType': 'EAN13',
      },
    );
    final data = response.data;
    final list = (data is Map<String, dynamic> ? data['variants'] : null) as List?;
    return list
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [];
  }

  /// Cập nhật hàng loạt biến thể (PATCH /products/templates/:id/variants/bulk).
  Future<void> bulkUpdateVariants(
    String templateId,
    List<Map<String, dynamic>> rows,
  ) async {
    await _dio.patch(
      '/products/templates/$templateId/variants/bulk',
      data: {'variants': rows},
    );
  }

  /// Nạp tồn đầu kỳ rồi áp dụng luôn (POST /inventory/opening-sheets, apply=true).
  Future<void> createOpeningStock({
    required String variantId,
    required int quantity,
    required String unitCost,
    String? note,
  }) async {
    await _dio.post(
      '/inventory/opening-sheets',
      data: {
        'apply': true,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'items': [
          {
            'variantId': variantId,
            'quantity': quantity,
            'unitCost': unitCost,
          },
        ],
      },
    );
  }
}
