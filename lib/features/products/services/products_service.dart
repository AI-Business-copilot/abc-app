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
    final response = await _dio.get('/products/attributes');
    final data = response.data;
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
}
