// DDE-Mart customer app — rental + ride screens (original).
//
// Rental meta/packages booking; ride request (source/destination) with
// tracking + cancel while placed/accepted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'helpers.dart';
import 'transport.dart';
class RentalScreen extends ConsumerStatefulWidget {
  const RentalScreen({super.key});

  @override
  ConsumerState<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends ConsumerState<RentalScreen> {
  final _source = TextEditingController();
  final _destination = TextEditingController();
  int? _packageId;
  bool _busy = false;

  @override
  void dispose() {
    _source.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a rental')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(transportApiProvider).rentalMeta(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final packages = apiList(snapshot.data!['packages']);
          _packageId ??= packages.isEmpty ? null : packages.first['id'] as int;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _packageId,
                items: [
                  for (final p in packages)
                    DropdownMenuItem(
                      value: p['id'] as int,
                      child: Text('${p['name']} · ${p['base_fare']}'),
                    ),
                ],
                onChanged: (value) => setState(() => _packageId = value),
                decoration: const InputDecoration(labelText: 'Package'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _source, decoration: const InputDecoration(labelText: 'Pickup')),
              const SizedBox(height: 12),
              TextField(
                controller: _destination,
                decoration: const InputDecoration(labelText: 'Dropoff (optional)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy || _packageId == null
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await ref.read(transportApiProvider).rentalBook({
                            'package_id': _packageId,
                            'source': _source.text.trim(),
                            if (_destination.text.trim().isNotEmpty)
                              'destination': _destination.text.trim(),
                            'booking_at': DateTime.now()
                                .add(const Duration(hours: 2))
                                .toIso8601String(),
                          });
                          if (context.mounted) context.push('/rental/orders');
                        } catch (e) {
                          if (context.mounted) failSnack(context, e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? 'Booking…' : 'Book rental'),
              ),
              TextButton(
                onPressed: () => context.push('/rental/orders'),
                child: const Text('My rentals'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RentalOrdersScreen extends ConsumerWidget {
  const RentalOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My rentals')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(transportApiProvider).rentalOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No rentals.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['number'] ?? ''}'),
                    subtitle: Text('${row['status']} · ${row['total']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/rental/order/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RentalTrackScreen extends ConsumerWidget {
  const RentalTrackScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(transportApiProvider).rentalTrack(orderId),
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
              const SizedBox(height: 8),
              DriverCard(
                driver: order['driver'] is Map
                    ? Map<String, dynamic>.from(order['driver'] as Map)
                    : null,
              ),
              const SizedBox(height: 4),
              for (final entry in history)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to_status']}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RideScreen extends ConsumerStatefulWidget {
  const RideScreen({super.key});

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ConsumerState<RideScreen> {
  final _source = TextEditingController();
  final _destination = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _source.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request a ride')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _source, decoration: const InputDecoration(labelText: 'Pickup')),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(labelText: 'Dropoff'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final ride = await ref.read(transportApiProvider).rideRequest({
                        'source': _source.text.trim(),
                        'destination': _destination.text.trim(),
                      });
                      if (context.mounted) context.push('/ride/${ride['id']}');
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Requesting…' : 'Request ride'),
          ),
          TextButton(
            onPressed: () => context.push('/rides'),
            child: const Text('My rides'),
          ),
        ],
      ),
    );
  }
}

class RidesScreen extends ConsumerWidget {
  const RidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My rides')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(transportApiProvider).rides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('No rides.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['number'] ?? ''}'),
                    subtitle: Text('${row['status']} · ${row['total']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/ride/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RideTrackScreen extends ConsumerStatefulWidget {
  const RideTrackScreen({super.key, required this.rideId});

  final int rideId;

  @override
  ConsumerState<RideTrackScreen> createState() => _RideTrackScreenState();
}

class _RideTrackScreenState extends ConsumerState<RideTrackScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(transportApiProvider).rideTrack(widget.rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final ride = snapshot.data!;
          final history = apiList(ride['history']);
          final cancellable =
              ride['status'] == 'placed' || ride['status'] == 'accepted';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${ride['number'] ?? ''} · ${ride['status']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Total ${ride['total']}'),
              const SizedBox(height: 8),
              DriverCard(
                driver: ride['driver'] is Map
                    ? Map<String, dynamic>.from(ride['driver'] as Map)
                    : null,
              ),
              const SizedBox(height: 4),
              for (final entry in history)
                ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text('${entry['to_status']}'),
                ),
              if (cancellable)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref
                                .read(transportApiProvider)
                                .rideCancel(widget.rideId);
                            if (mounted) setState(() {});
                          } catch (e) {
                            if (context.mounted) failSnack(context, e);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Cancel ride'),
                ),
            ],
          );
        },
      ),
    );
  }
}
