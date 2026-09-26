// DDE-Mart customer app — cart state + server quote (original).
//
// Cart lives client-side (product + addon selection); every total shown at
// checkout comes from POST /cart/quote — the server is the source of truth.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';

class CartLine {
  CartLine({required this.productId, this.quantity = 1, List<int>? addonIds})
      : addonIds = addonIds ?? [];

  final int productId;
  final int quantity;
  final List<int> addonIds;

  String get key => '$productId:${(List.of(addonIds)..sort()).join(',')}';

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'addons': addonIds,
      };
}

class CartState {
  const CartState({this.lines = const [], this.couponCode});

  final List<CartLine> lines;
  final String? couponCode;

  int get count => lines.fold(0, (sum, line) => sum + line.quantity);
  bool get isEmpty => lines.isEmpty;
}

class CartStore extends StateNotifier<CartState> {
  CartStore() : super(const CartState()) {
    _restore();
  }

  static const _key = 'cart.v1';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;

      final decoded = (jsonDecode(raw) as List);
      final lines = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => CartLine(
                productId: (m['product_id'] as num).toInt(),
                quantity: ((m['quantity'] as num?) ?? 1).toInt(),
                addonIds: ((m['addons'] as List?) ?? [])
                    .map((a) => (a as num).toInt())
                    .toList(),
              ))
          .toList();
      state = CartState(lines: lines);
    } catch (_) {
      // Corrupt cache never blocks shopping.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  void add({required int productId, List<int> addonIds = const []}) {
    final candidate = CartLine(productId: productId, addonIds: addonIds);
    final lines = List.of(state.lines);
    final index = lines.indexWhere((line) => line.key == candidate.key);
    if (index >= 0) {
      final existing = lines[index];
      lines[index] = CartLine(
        productId: existing.productId,
        quantity: (existing.quantity + 1).clamp(1, 99),
        addonIds: existing.addonIds,
      );
    } else {
      lines.add(candidate);
    }
    state = CartState(lines: lines, couponCode: state.couponCode);
    _persist();
  }

  void setQuantity(String key, int quantity) {
    final lines = List.of(state.lines);
    final index = lines.indexWhere((line) => line.key == key);
    if (index < 0) return;
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      final existing = lines[index];
      lines[index] = CartLine(
        productId: existing.productId,
        quantity: quantity.clamp(1, 99),
        addonIds: existing.addonIds,
      );
    }
    state = CartState(lines: lines, couponCode: state.couponCode);
    _persist();
  }

  void remove(String key) => setQuantity(key, 0);

  void setCoupon(String? code) {
    state = CartState(
      lines: state.lines,
      couponCode: (code == null || code.trim().isEmpty) ? null : code.trim(),
    );
    _persist();
  }

  void clear() {
    state = const CartState();
    _persist();
  }

  List<Map<String, dynamic>> toJson() =>
      state.lines.map((line) => line.toJson()).toList();
}

final cartStoreProvider = StateNotifierProvider<CartStore, CartState>(
  (ref) => CartStore(),
);

class Quote {
  Quote({
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.delivery,
    required this.tax,
    required this.total,
    this.coupon,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        lines: (((json['lines'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()),
        subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
        discount: ((json['discount'] as num?) ?? 0).toDouble(),
        delivery: ((json['delivery'] as num?) ?? 0).toDouble(),
        tax: ((json['tax'] as num?) ?? 0).toDouble(),
        total: ((json['total'] as num?) ?? 0).toDouble(),
        coupon: json['coupon'] == null
            ? null
            : Map<String, dynamic>.from(json['coupon'] as Map),
      );

  final List<Map<String, dynamic>> lines;
  final double subtotal;
  final double discount;
  final double delivery;
  final double tax;
  final double total;
  final Map<String, dynamic>? coupon;
}

class CheckoutApi {
  CheckoutApi(this._dio);

  final Dio _dio;

  Future<Quote> quote({
    required List<Map<String, dynamic>> items,
    String? couponCode,
  }) async {
    final response = await _dio.post('/cart/quote', data: {
      'items': items,
      if (couponCode case final code) 'coupon_code': code,
    });
    return Quote.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
  }

  Future<Map<String, dynamic>> place({
    required List<Map<String, dynamic>> items,
    String? couponCode,
    required String paymentMethod,
    String? address,
    String? notes,
    DateTime? scheduledAt,
  }) async {
    final response = await _dio.post('/checkout', data: {
      'items': items,
      if (couponCode case final code) 'coupon_code': code,
      'payment_method': paymentMethod,
      if (address != null && address.isNotEmpty) 'address': {'address': address},
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
    });
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }
}

final checkoutApiProvider = Provider<CheckoutApi>(
  (ref) => CheckoutApi(ref.watch(dioProvider)),
);

final quoteProvider = FutureProvider<Quote?>((ref) async {
  final cart = ref.watch(cartStoreProvider);
  if (cart.isEmpty) return null;
  return ref.watch(checkoutApiProvider).quote(
        items: cart.lines.map((line) => line.toJson()).toList(),
        couponCode: cart.couponCode,
      );
});
