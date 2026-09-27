// DDE-Mart customer app — catalog API (original).
//
// Public browse: sections, categories, stores, products + details.
// Shapes mirror admin-panel API resources (data envelopes, paginated lists).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

Map<String, dynamic> _item(Map e) => Map<String, dynamic>.from(e);

List<Map<String, dynamic>> _list(Response r) =>
    (((r.data as Map)['data'] as List?) ?? []).map((e) => _item(e as Map)).toList();

/// Query map without nulls (blank strings count as absent).
Map<String, Object> _q(Map<String, Object?> values) {
  values.removeWhere((key, value) => value == null || value == '');
  return values.cast<String, Object>();
}

class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> sections() async =>
      _list(await _dio.get('/sections'));

  Future<List<Map<String, dynamic>>> categories({int? sectionId}) async =>
      _list(await _dio.get('/categories', queryParameters: _q({
        'section_id': sectionId,
      })));

  Future<List<Map<String, dynamic>>> stores({int? sectionId, String? q}) async =>
      _list(await _dio.get('/stores', queryParameters: _q({
        'section_id': sectionId,
        'q': q,
      })));

  Future<Map<String, dynamic>> store(int id) async {
    final r = await _dio.get('/stores/$id');
    return _item((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> products({
    int? sectionId,
    int? categoryId,
    int? storeId,
    String? q,
  }) async =>
      _list(await _dio.get('/products', queryParameters: _q({
        'section_id': sectionId,
        'category_id': categoryId,
        'store_id': storeId,
        'q': q,
      })));

  Future<Map<String, dynamic>> product(int id) async {
    final r = await _dio.get('/products/$id');
    return _item((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> productReviews(int id, {int page = 1}) async {
    final r = await _dio.get('/products/$id/reviews', queryParameters: {'page': page});
    return _list((r.data as Map)['data']);
  }

  Future<List<Map<String, dynamic>>> storeReviews(int id, {int page = 1}) async {
    final r = await _dio.get('/stores/$id/reviews', queryParameters: {'page': page});
    return _list((r.data as Map)['data']);
  }
}

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(ref.watch(dioProvider)),
);

/// Effective unit price: discount when set, else list price.
double sellingPrice(Map<String, dynamic> product) {
  final discount = (product['discount_price'] as num?)?.toDouble();
  if (discount != null && discount > 0) return discount;
  return (product['price'] as num?)?.toDouble() ?? 0;
}
