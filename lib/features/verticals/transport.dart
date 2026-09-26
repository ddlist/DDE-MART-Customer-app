// DDE-Mart customer app — transport verticals (original).
//
// Parcel (meta/quote/book/track/cancel), rental (meta/book/track) and ride
// (request/track/cancel) against /parcel/*, /rental/*, /rides/*.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'helpers.dart';


class TransportApi {
  TransportApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> parcelMeta() async {
    final r = await _dio.get('/parcel/meta');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<double> parcelQuote({required int weightId, required double km}) async {
    final r = await _dio.post('/parcel/quote', data: {
      'weight_id': weightId,
      'distance_km': km,
    });
    return (((r.data as Map)['data'] as Map)['charge'] as num).toDouble();
  }

  Future<Map<String, dynamic>> parcelBook(Map<String, Object?> fields) async {
    final r = await _dio.post('/parcel/book', data: fields);
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> parcelOrders() async {
    final r = await _dio.get('/parcel/orders');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> parcelTrack(int id) async {
    final r = await _dio.get('/parcel/orders/$id');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<void> parcelCancel(int id) async {
    await _dio.post('/parcel/orders/$id/cancel');
  }

  Future<Map<String, dynamic>> rentalMeta() async {
    final r = await _dio.get('/rental/meta');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<Map<String, dynamic>> rentalBook(Map<String, Object?> fields) async {
    final r = await _dio.post('/rental/book', data: fields);
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> rentalOrders() async {
    final r = await _dio.get('/rental/orders');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> rentalTrack(int id) async {
    final r = await _dio.get('/rental/orders/$id');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<Map<String, dynamic>> rideRequest(Map<String, Object?> fields) async {
    final r = await _dio.post('/rides/request', data: fields);
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> rides() async {
    final r = await _dio.get('/rides');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> rideTrack(int id) async {
    final r = await _dio.get('/rides/$id');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<void> rideCancel(int id) async {
    await _dio.post('/rides/$id/cancel');
  }
}

final transportApiProvider = Provider<TransportApi>(
  (ref) => TransportApi(ref.watch(dioProvider)),
);

InputDecoration _label(String text) => InputDecoration(labelText: text);

/// Hub listing every transport + life vertical.
class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in [
            ('Parcel', Icons.local_shipping_outlined, '/parcel'),
            ('Rental', Icons.car_rental_outlined, '/rental'),
            ('Ride', Icons.local_taxi_outlined, '/ride'),
            ('Home services', Icons.handyman_outlined, '/life/services'),
            ('Dine-in', Icons.restaurant_outlined, '/life/dinein'),
            ('Gifts', Icons.card_giftcard_outlined, '/life/gifts'),
            ('Favorites', Icons.favorite_outline, '/life/favorites'),
            ('Support chat', Icons.chat_outlined, '/life/chat'),
            ('Safety', Icons.sos_outlined, '/life/safety'),
          ])
            Card(
              child: ListTile(
                leading: Icon(entry.$2),
                title: Text(entry.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(entry.$3),
              ),
            ),
        ],
      ),
    );
  }
}

class ParcelScreen extends ConsumerStatefulWidget {
  const ParcelScreen({super.key});

  @override
  ConsumerState<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends ConsumerState<ParcelScreen> {
  final _sender = TextEditingController(text: '');
  final _senderAddr = TextEditingController();
  final _receiver = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverAddr = TextEditingController();
  final _km = TextEditingController(text: '4');
  int? _weightId;
  bool _busy = false;

  @override
  void dispose() {
    _sender.dispose();
    _senderAddr.dispose();
    _receiver.dispose();
    _receiverPhone.dispose();
    _receiverAddr.dispose();
    _km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send a parcel')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(transportApiProvider).parcelMeta(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final meta = snapshot.data!;
          final weights = apiList(meta['weights']);
          _weightId ??= weights.isEmpty ? null : weights.first['id'] as int;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _sender, decoration: _label('Sender name')),
              const SizedBox(height: 12),
              TextField(controller: _senderAddr, decoration: _label('Pickup address')),
              const SizedBox(height: 12),
              TextField(controller: _receiver, decoration: _label('Receiver name')),
              const SizedBox(height: 12),
              TextField(
                controller: _receiverPhone,
                keyboardType: TextInputType.phone,
                decoration: _label('Receiver phone'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _receiverAddr, decoration: _label('Dropoff address')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _weightId,
                items: [
                  for (final w in weights)
                    DropdownMenuItem(value: w['id'] as int, child: Text('${w['title']}')),
                ],
                onChanged: (value) => setState(() => _weightId = value),
                decoration: _label('Weight slab'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _km,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _label('Distance (km)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy || _weightId == null
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final booked = await ref.read(transportApiProvider).parcelBook({
                            'sender_name': _sender.text.trim(),
                            'sender_address': _senderAddr.text.trim(),
                            'receiver_name': _receiver.text.trim(),
                            'receiver_phone': _receiverPhone.text.trim(),
                            'receiver_address': _receiverAddr.text.trim(),
                            'weight_id': _weightId,
                            'distance_km': double.tryParse(_km.text.trim()) ?? 0,
                          });
                          if (context.mounted) {
                            context.push('/parcel/order/${booked['id']}');
                          }
                        } catch (e) {
                          if (context.mounted) failSnack(context, e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? 'Booking…' : 'Book pickup'),
              ),
              TextButton(
                onPressed: () => context.push('/parcel/orders'),
                child: const Text('My parcels'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ParcelOrdersScreen extends ConsumerWidget {
  const ParcelOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My parcels')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(transportApiProvider).parcelOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No parcels.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['number'] ?? ''}'),
                    subtitle: Text('${row['status']} · ${row['total']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/parcel/order/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ParcelTrackScreen extends ConsumerStatefulWidget {
  const ParcelTrackScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<ParcelTrackScreen> createState() => _ParcelTrackScreenState();
}

class _ParcelTrackScreenState extends ConsumerState<ParcelTrackScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcel')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(transportApiProvider).parcelTrack(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final order = snapshot.data!;
          final history = apiList(order['history']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${order['number'] ?? ''} · ${order['status']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Total ${order['total']}'),
              const SizedBox(height: 12),
              for (final entry in history)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to_status']}'),
                ),
              if (order['status'] == 'placed')
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref
                                .read(transportApiProvider)
                                .parcelCancel(widget.orderId);
                            if (mounted) setState(() {});
                          } catch (e) {
                            if (context.mounted) failSnack(context, e);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Cancel'),
                ),
            ],
          );
        },
      ),
    );
  }
}
