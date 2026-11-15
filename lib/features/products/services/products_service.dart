import 'package:abc_app/core/network/api_client.dart';
import 'package:abc_app/features/products/models/product_model.dart';

class ProductsService {
  final _dio = ApiClient().dio;

  Future<List<ProductItem>> getProducts({String? keyword}) async {
    final response = await _dio.get(
      '/products/list',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty) 'q': keyword.trim(),
        'pageSize': 50,
      },
    );

    final data = response.data;
    // Backend tra ve { items: [...], stats: {...}, categories: [...], pagination: {...} }
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
}
