// DDE-Mart customer app — life verticals (original).
//
// On-demand services (categories/services/book/track), dine-in table booking,
// gift cards (buy/redeem) and favorites (toggle + list).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'helpers.dart';

class LifeApi {
  LifeApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> serviceCategories() async {
    final r = await _dio.get('/service-categories');
    return apiList((r.data as Map)['data']);
  }

  Future<List<Map<String, dynamic>>> services({int? categoryId}) async {
    final r = await _dio.get('/services', queryParameters: cleanMap({
      'category_id': categoryId,
    }));
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> serviceBook({
    required int serviceId,
    required String address,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final r = await _dio.post('/services/book', data: {
      'service_id': serviceId,
      'address': address,
      'scheduled_at': scheduledAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> serviceBookings() async {
    final r = await _dio.get('/service-bookings');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> serviceTrack(int id) async {
    final r = await _dio.get('/service-bookings/$id');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<Map<String, dynamic>> dineinBook({
    int? storeId,
    required int guests,
    required DateTime bookedFor,
    String? occasion,
    String? specialRequest,
  }) async {
    final r = await _dio.post('/dinein/book', data: cleanMap({
      'store_id': storeId,
      'guests': guests,
      'booked_for': bookedFor.toIso8601String(),
      'occasion': occasion,
      'special_request': specialRequest,
    }));
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> dineinBookings() async {
    final r = await _dio.get('/dinein/bookings');
    return apiList((r.data as Map)['data']);
  }

  Future<List<Map<String, dynamic>>> giftCards() async {
    final r = await _dio.get('/gift-cards');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> giftBuy({required int giftId}) async {
    final r = await _dio.post('/gifts/buy', data: {
      'gift_id': giftId,
      'payment_method': 'cod',
    });
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<double> giftRedeem(String code) async {
    final r = await _dio.post('/gifts/redeem', data: {'code': code});
    return (((r.data as Map)['data'] as Map)['credited'] as num).toDouble();
  }

  Future<Map<String, List<Map<String, dynamic>>>> favorites() async {
    final r = await _dio.get('/favorites');
    final data = (r.data as Map)['data'] as Map;
    return {
      'products': apiList(data['products']),
      'stores': apiList(data['stores']),
    };
  }

  Future<void> favoriteToggle({required String type, required int id}) async {
    await _dio.post('/favorites/toggle', data: {'type': type, 'id': id});
  }
}

final lifeApiProvider = Provider<LifeApi>(
  (ref) => LifeApi(ref.watch(dioProvider)),
);

class LifeServicesScreen extends ConsumerWidget {
  const LifeServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home services')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(lifeApiProvider).serviceCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['title']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/life/services/${row['id']}'),
                  ),
                ),
              TextButton(
                onPressed: () => context.push('/life/bookings'),
                child: const Text('My bookings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LifeServiceListScreen extends ConsumerWidget {
  const LifeServiceListScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(lifeApiProvider).services(categoryId: categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No services.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['title']}'),
                    subtitle: Text('${row['price']} · ${row['provider']?['name'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/life/service/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LifeServiceBookScreen extends ConsumerStatefulWidget {
  const LifeServiceBookScreen({super.key, required this.serviceId});

  final int serviceId;

  @override
  ConsumerState<LifeServiceBookScreen> createState() => _LifeServiceBookScreenState();
}

class _LifeServiceBookScreenState extends ConsumerState<LifeServiceBookScreen> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Service address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final booking =
                          await ref.read(lifeApiProvider).serviceBook(
                                serviceId: widget.serviceId,
                                address: _address.text.trim(),
                                scheduledAt: DateTime.now().add(const Duration(days: 1)),
                                notes: _notes.text.trim(),
                              );
                      if (context.mounted) {
                        context.push('/life/booking/${booking['id']}');
                      }
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Booking…' : 'Book for tomorrow'),
          ),
        ],
      ),
    );
  }
}

class LifeBookingsScreen extends ConsumerWidget {
  const LifeBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My service bookings')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(lifeApiProvider).serviceBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No bookings.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['number'] ?? ''}'),
                    subtitle: Text('${row['status']} · ${row['total']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/life/booking/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LifeBookingTrackScreen extends ConsumerWidget {
  const LifeBookingTrackScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(lifeApiProvider).serviceTrack(bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final booking = snapshot.data!;
          final timeline = apiList(booking['timeline']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${booking['number'] ?? ''} · ${booking['status']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Provider: ${booking['provider']?['name'] ?? '—'}'),
              Text('Service: ${booking['service']?['title'] ?? '—'}'),
              const SizedBox(height: 12),
              for (final entry in timeline)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to'] ?? entry['to_status']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class DineinScreen extends ConsumerStatefulWidget {
  const DineinScreen({super.key});

  @override
  ConsumerState<DineinScreen> createState() => _DineinScreenState();
}

class _DineinScreenState extends ConsumerState<DineinScreen> {
  final _guests = TextEditingController(text: '2');
  bool _busy = false;

  @override
  void dispose() {
    _guests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a table')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _guests,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Guests'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref.read(lifeApiProvider).dineinBook(
                            guests: int.tryParse(_guests.text.trim()) ?? 2,
                            bookedFor: DateTime.now().add(const Duration(days: 1)),
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Table requested.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Requesting…' : 'Request table for tomorrow'),
          ),
          const SizedBox(height: 16),
          Text('My requests', style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.watch(lifeApiProvider).dineinBookings(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(apiMessage(snapshot.error!));
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Text('No requests.');
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text('Party of ${row['guests']}'),
                        subtitle: Text('${row['status']}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key});

  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gifts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Buy a gift card', style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.watch(lifeApiProvider).giftCards(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(apiMessage(snapshot.error!));
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Text('No gift cards.');
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text('${row['title']} · ${row['amount']}'),
                        trailing: FilledButton.tonal(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final bought = await ref
                                        .read(lifeApiProvider)
                                        .giftBuy(giftId: row['id'] as int);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Gift code: ${bought['code']}'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) failSnack(context, e);
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          child: const Text('Buy'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Redeem', style: Theme.of(context).textTheme.titleMedium),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Gift code')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final credited = await ref
                          .read(lifeApiProvider)
                          .giftRedeem(_code.text.trim().toUpperCase());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Credited $credited to wallet.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Redeem to wallet'),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Map<String, List<Map<String, dynamic>>>? _favorites;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      _favorites = await ref.read(lifeApiProvider).favorites();
    } catch (e) {
      if (mounted) failSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(String type, int id) async {
    try {
      await ref.read(lifeApiProvider).favoriteToggle(type: type, id: id);
      await _load();
    } catch (e) {
      if (mounted) failSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: _busy && favorites == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Products', style: Theme.of(context).textTheme.titleMedium),
                for (final p in favorites?['products'] ?? [])
                  Card(
                    child: ListTile(
                      title: Text('${p['name']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => _toggle('product', p['id'] as int),
                      ),
                      onTap: () => context.push('/product/${p['id']}'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Stores', style: Theme.of(context).textTheme.titleMedium),
                for (final s in favorites?['stores'] ?? [])
                  Card(
                    child: ListTile(
                      title: Text('${s['name']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () => _toggle('store', s['id'] as int),
                      ),
                      onTap: () => context.push('/store/${s['id']}'),
                    ),
                  ),
                if ((favorites?['products'] ?? []).isEmpty &&
                    (favorites?['stores'] ?? []).isEmpty &&
                    !_busy)
                  const Text('No favorites yet.'),
              ],
            ),
    );
  }
}
