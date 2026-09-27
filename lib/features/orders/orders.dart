// DDE-Mart customer app — orders API + screens (original).
//
// GET /orders (paginated), GET /orders/{id} (items + history timeline),
// POST /orders/{id}/cancel (placed only), POST /reviews (completed orders).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../verticals/helpers.dart';

class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> orders() async {
    final response = await _dio.get('/orders');
    return (((response.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> order(int id) async {
    final response = await _dio.get('/orders/$id');
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  Future<void> cancel(int id) async {
    await _dio.post('/orders/$id/cancel');
  }

  Future<void> review({
    required int orderId,
    required int productId,
    required int rating,
    String? comment,
  }) async {
    await _dio.post('/reviews', data: {
      'order_id': orderId,
      'product_id': productId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}

final ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(dioProvider)),
);

final ordersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(ordersApiProvider).orders();
});

final orderProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return ref.watch(ordersApiProvider).order(id);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiMessage(e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(ordersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rows) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(ordersProvider),
          child: rows.isEmpty
              ? const Center(child: Text('No orders yet.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final order in rows)
                      Card(
                        child: ListTile(
                          title: Text('${order['number'] ?? '#${order['id']}'}'),
                          subtitle: Text('${order['status']} · ${order['total']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.safePush('/order/${order['id']}'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiMessage(e))),
        data: (data) {
          final items = ((data['items'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final history = ((data['history'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final status = '${data['status']}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${data['number'] ?? ''} · $status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Total ${data['total']}'),
              const SizedBox(height: 8),
              DriverCard(
                driver: data['driver'] is Map
                    ? Map<String, dynamic>.from(data['driver'] as Map)
                    : null,
              ),
              const SizedBox(height: 4),
              for (final item in items)
                ListTile(
                  title: Text('${item['name']} × ${item['quantity']}'),
                  trailing: Text('${item['subtotal'] ?? item['price']}'),
                ),
              const SizedBox(height: 12),
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              for (final entry in history)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to_status']}'),
                ),
              if (status == 'placed') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref.read(ordersApiProvider).cancel(widget.orderId);
                            ref.invalidate(orderProvider(widget.orderId));
                            ref.invalidate(ordersProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(apiMessage(e))),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Cancel order'),
                ),
              ],
              if (status == 'completed' && items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Rate items', style: Theme.of(context).textTheme.titleMedium),
                for (final item in items)
                  if (item['product_id'] != null)
                    _ReviewRow(
                      orderId: widget.orderId,
                      productId: item['product_id'] as int,
                      productName: '${item['name']}',
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewRow extends ConsumerStatefulWidget {
  const _ReviewRow({
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  final int orderId;
  final int productId;
  final String productName;

  @override
  ConsumerState<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends ConsumerState<_ReviewRow> {
  int _rating = 5;
  bool _sent = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (_sent) return ListTile(title: Text(widget.productName), trailing: const Text('★ rated'));

    return ListTile(
      title: Text(widget.productName),
      subtitle: Row(
        children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
              icon: Icon(
                star <= _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => setState(() => _rating = star),
            ),
        ],
      ),
      trailing: _busy
          ? const CircularProgressIndicator()
          : IconButton(
              icon: const Icon(Icons.send_outlined),
              onPressed: () async {
                setState(() => _busy = true);
                try {
                  await ref.read(ordersApiProvider).review(
                        orderId: widget.orderId,
                        productId: widget.productId,
                        rating: _rating,
                      );
                  setState(() => _sent = true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(apiMessage(e))),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
            ),
    );
  }
}
