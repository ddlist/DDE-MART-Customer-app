// DDE-Mart customer app — cart + checkout screens (original).
//
// Cart edits are local; the quote (server math) drives checkout. Payment is
// COD or wallet balance in this version; gateway redirects land next with
// webview + deep-link return.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import 'cart.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final line in cart.lines)
                  Card(
                    child: ListTile(
                      title: Text('Product #${line.productId}'),
                      subtitle: line.addonIds.isEmpty
                          ? null
                          : Text('Extras: ${line.addonIds.join(', ')}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => ref
                                .read(cartStoreProvider.notifier)
                                .setQuantity(line.key, line.quantity - 1),
                          ),
                          Text('${line.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => ref
                                .read(cartStoreProvider.notifier)
                                .setQuantity(line.key, line.quantity + 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.safePush('/checkout'),
                  child: const Text('Checkout'),
                ),
              ],
            ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _coupon = TextEditingController();
  String _method = 'cod';
  bool _busy = false;
  bool _schedule = false;
  DateTime? _scheduledAt;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final cart = ref.read(cartStoreProvider);
    if (cart.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final order = await ref.read(checkoutApiProvider).place(
            items: cart.lines.map((line) => line.toJson()).toList(),
            couponCode: cart.couponCode,
            paymentMethod: _method,
            address: _address.text.trim(),
            notes: _notes.text.trim(),
            scheduledAt: _schedule ? _scheduledAt : null,
          );
      ref.read(cartStoreProvider.notifier).clear();
      router.push('/order-success/${order['id']}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(quoteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Delivery address'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coupon,
                  decoration: const InputDecoration(labelText: 'Coupon code'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  ref.read(cartStoreProvider.notifier).setCoupon(_coupon.text);
                  ref.invalidate(quoteProvider);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Schedule for later'),
            value: _schedule,
            onChanged: (value) => setState(() {
              _schedule = value;
              _scheduledAt = null;
            }),
          ),
          if (_schedule)
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_outlined),
              label: Text(
                _scheduledAt == null
                    ? 'Pick date & time'
                    : '${_scheduledAt!.day}/${_scheduledAt!.month} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
              ),
              onPressed: () async {
                final pickerContext = context;
                final date = await showDatePicker(
                  context: pickerContext,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 7)),
                );
                if (date == null || !pickerContext.mounted) return;
                final time = await showTimePicker(
                  context: pickerContext,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null || !pickerContext.mounted) return;
                setState(() {
                  _scheduledAt = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute,
                  );
                });
              },
            ),
          const SizedBox(height: 16),
          Text('Payment', style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<String>(
            groupValue: _method,
            onChanged: (value) => setState(() => _method = value ?? 'cod'),
            child: const Column(
              children: [
                RadioListTile<String>(
                  title: Text('Cash on delivery'),
                  value: 'cod',
                ),
                RadioListTile<String>(
                  title: Text('Wallet balance'),
                  value: 'wallet',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          quote.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (q) {
              if (q == null) return const Text('Cart is empty.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row('Subtotal', q.subtotal),
                  _row('Discount', -q.discount),
                  _row('Delivery', q.delivery),
                  _row('Tax', q.tax),
                  _row('Total', q.total, bold: true),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _place,
                    child: Text(_busy ? 'Placing…' : 'Place order'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(2), style: style),
        ],
      ),
    );
  }
}

