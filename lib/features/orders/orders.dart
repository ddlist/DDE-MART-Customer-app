// DDE-Mart customer app — orders API + screens (original).
//
// GET /orders (paginated), GET /orders/{id} (items + history timeline),
// POST /orders/{id}/cancel (placed only), POST /reviews (completed orders).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';
import '../cart/cart.dart';
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
          onRefresh: () async {
            ref.invalidate(ordersProvider);
          },
          child: rows.isEmpty
              ? const EmptyState(
                  message: 'No orders yet. Your food journey starts here.',
                  icon: Icons.receipt_long_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final order in rows)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              context.safePush('/order/${order['id']}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${order['number'] ?? 'Order #${order['id']}'}',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ),
                                    StatusChip(
                                        status:
                                            '${order['status'] ?? ''}'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${(order['items'] as List?)?.length ?? '—'} items · ${order['total'] ?? ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
          // API v1 sends `timeline` ({from,to,note,at}); accept legacy
          // `history` ({to_status}) too so nothing renders empty.
          final rawHistory = (data['timeline'] as List?) ??
              (data['history'] as List?) ??
              [];
          final history = rawHistory
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final status = '${data['status']}';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderProvider(widget.orderId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${data['number'] ?? 'Order #${data['id']}'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge,
                              ),
                            ),
                            StatusChip(status: status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placed ${agoText(data['created_at'] as String?)}'
                          '${data['payment_method'] != null ? ' · ${_pretty(data['payment_method'])}' : ''}',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        if (data['scheduled_at'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                  Icons.schedule_outlined,
                                  size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Scheduled: ${data['scheduled_at']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DriverCard(
                  driver: data['driver'] is Map
                      ? Map<String, dynamic>.from(
                          data['driver'] as Map)
                      : null,
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Tracking',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 8),
                          for (var i = 0; i < history.length; i++)
                            _TimelineTile(
                              entry: history[i],
                              last: i == history.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              8, 8, 8, 0),
                          child: Text('Items',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                        ),
                        for (final item in items)
                          ListTile(
                            title: Text(
                                '${item['name']} × ${item['quantity']}'),
                            subtitle: _extrasText(item) == null
                                ? null
                                : Text(_extrasText(item)!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                            trailing: Text(
                              '${item['subtotal'] ?? item['price'] ?? ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text('Bill details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        const SizedBox(height: 8),
                        _billRow('Subtotal', data['subtotal']),
                        _billRow(
                            'Discount', data['discount'],
                            negative: true),
                        _billRow('Delivery',
                            data['delivery_charge']),
                        _billRow('Tax', data['tax']),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                            Text('${data['total'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold)),
                          ],
                        ),
                        if (data['coupon_code'] != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 6),
                            child: Text(
                              'Coupon applied: ${data['coupon_code']}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (data['address'] != null &&
                    '${data['address']}'.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.location_on_outlined),
                      title: const Text('Delivery address'),
                      subtitle:
                          Text('${data['address']}'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (status == 'placed')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(
                                      () => _busy = true);
                                  try {
                                    await ref
                                        .read(ordersApiProvider)
                                        .cancel(widget.orderId);
                                    ref.invalidate(orderProvider(
                                        widget.orderId));
                                    ref.invalidate(
                                        ordersProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                              context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                apiMessage(
                                                    e))),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() =>
                                          _busy = false);
                                    }
                                  }
                                },
                          child:
                              const Text('Cancel order'),
                        ),
                      ),
                    if (status == 'placed')
                      const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: items.isEmpty
                            ? null
                            : () {
                                final notifier = ref.read(
                                    cartStoreProvider
                                        .notifier);
                                for (final item in items) {
                                  final pid =
                                      (item['product_id']
                                              as num?)
                                          ?.toInt();
                                  if (pid == null) continue;
                                  notifier.add(
                                      productId: pid);
                                  final qty =
                                      (item['quantity']
                                              as num?)
                                          ?.toInt() ??
                                      1;
                                  if (qty > 1) {
                                    notifier.setQuantity(
                                        '$pid:', qty);
                                  }
                                }
                                context.safePush('/cart');
                              },
                        child: const Text('Reorder'),
                      ),
                    ),
                  ],
                ),
                if (status == 'completed' &&
                    items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Rate items',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium),
                  for (final item in items)
                    if (item['product_id'] != null)
                      _ReviewRow(
                        orderId: widget.orderId,
                        productId:
                            item['product_id'] as int,
                        productName: '${item['name']}',
                      ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _pretty(Object? value) {
  final s = '$value';
  if (s.length <= 4) return s.toUpperCase();
  return s.replaceAll('_', ' ');
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.value, {this.negative = false});

  final String label;
  final Object? value;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final amount = (value as num?)?.toDouble() ?? 0;
    if (negative && amount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${negative ? '-' : ''}${amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

Widget _billRow(String label, Object? value, {bool negative = false}) =>
    _BillRow(label, value, negative: negative);

String? _extrasText(Map<String, dynamic> item) {
  final extras = ((item['extras'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  if (extras.isEmpty) return null;
  return extras.map((e) => '${e['name']}').join(', ');
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.last});

  final Map<String, dynamic> entry;
  final bool last;

  static const _icons = {
    'placed': Icons.receipt_long_outlined,
    'accepted': Icons.thumb_up_outlined,
    'confirmed': Icons.thumb_up_outlined,
    'preparing': Icons.restaurant_outlined,
    'cooking': Icons.restaurant_outlined,
    'ready': Icons.dinner_dining_outlined,
    'ongoing': Icons.delivery_dining_outlined,
    'on_the_way': Icons.delivery_dining_outlined,
    'picked_up': Icons.delivery_dining_outlined,
    'shipped': Icons.local_shipping_outlined,
    'completed': Icons.check_circle_outline,
    'delivered': Icons.check_circle_outline,
    'cancelled': Icons.cancel_outlined,
    'canceled': Icons.cancel_outlined,
    'rejected': Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final to = '${entry['to'] ?? entry['to_status'] ?? ''}';
    final at = entry['at'] as String?;
    final note = entry['note'];
    final color = StatusChip.colorFor(to);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[to.toLowerCase()] ?? Icons.circle,
                  size: 16,
                  color: color,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pretty(to),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (at != null)
                    Text(
                      agoText(at),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (note != null && '$note'.isNotEmpty)
                    Text(
                      '$note',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
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
