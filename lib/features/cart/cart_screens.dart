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
import '../../core/widgets.dart';
import '../onboarding/onboarding.dart';
import 'cart.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear cart',
              onPressed: () {
                ref.read(cartStoreProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cart cleared.')),
                );
              },
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    message: 'Your cart is empty.',
                    icon: Icons.shopping_cart_outlined,
                  ),
                  FilledButton(
                    onPressed: () => context.safePush('/home'),
                    child: const Text('Browse food'),
                  ),
                ],
              ),
            )
          : FutureBuilder<List<CartLineDetail>>(
              future: ref.watch(cartDetailsProvider.future),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text(apiMessage(snapshot.error!)));
                }
                final details = snapshot.data ?? [];
                final subtotal = details.fold<double>(
                    0, (sum, d) => sum + d.lineTotal);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            for (final d in details) ...[
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ApiImage(
                                    path: d.product['image'] as String?,
                                    height: 72,
                                    width: 72,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    icon: Icons.fastfood_outlined,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (d.product['veg']
                                                is bool) ...[
                                              VegMark(
                                                  veg: d.product['veg']
                                                      as bool),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                '${d.product['name']}',
                                                maxLines: 2,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (d.addonNames.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    top: 2),
                                            child: Text(
                                              d.addonNames.join(', '),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        PriceText(
                                            price: d.unitPrice),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              size: 18),
                                          onPressed: () => ref
                                              .read(cartStoreProvider
                                                  .notifier)
                                              .setQuantity(d.line.key,
                                                  d.line.quantity - 1),
                                        ),
                                        Text('${d.line.quantity}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        IconButton(
                                          icon: const Icon(Icons.add,
                                              size: 18),
                                          onPressed: () => ref
                                              .read(cartStoreProvider
                                                  .notifier)
                                              .setQuantity(d.line.key,
                                                  d.line.quantity + 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    d.lineTotal.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (d != details.last)
                                const Divider(height: 24),
                            ],
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
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Item total'),
                                Text(subtotal.toStringAsFixed(2)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Delivery, taxes and discounts are calculated at checkout.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8),
                  ],
                ),
                child: FutureBuilder<List<CartLineDetail>>(
                  future: ref.watch(cartDetailsProvider.future),
                  builder: (context, snapshot) {
                    final details = snapshot.data ?? [];
                    final subtotal = details.fold<double>(
                        0, (sum, d) => sum + d.lineTotal);
                    return FilledButton(
                      onPressed: details.isEmpty
                          ? null
                          : () => context.safePush('/checkout'),
                      child: Text(
                          'Proceed to checkout · ${subtotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
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
    final saved = ref.watch(savedAddressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      Text('Delivery address',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (saved.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final a in saved)
                          ActionChip(
                            label: Text(
                              a,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => setState(
                                () => _address.text = a),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'House, street, area',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Remarks for the store (optional)',
                      prefixIcon: Icon(Icons.note_outlined),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined),
                      const SizedBox(width: 8),
                      Text('Delivery slot',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Schedule for later'),
                    subtitle: const Text('Default: as soon as possible'),
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
                          lastDate:
                              DateTime.now().add(const Duration(days: 7)),
                        );
                        if (date == null || !pickerContext.mounted) return;
                        final time = await showTimePicker(
                          context: pickerContext,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time == null || !pickerContext.mounted) return;
                        setState(() {
                          _scheduledAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_offer_outlined),
                      const SizedBox(width: 8),
                      Text('Offers',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _coupon,
                          decoration: const InputDecoration(
                              labelText: 'Coupon code'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          ref
                              .read(cartStoreProvider.notifier)
                              .setCoupon(_coupon.text);
                          ref.invalidate(quoteProvider);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined),
                        const SizedBox(width: 8),
                        Text('Payment method',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                      ],
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: _method,
                    onChanged: (value) =>
                        setState(() => _method = value ?? 'cod'),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          secondary:
                              const Icon(Icons.money_outlined),
                          title: const Text('Cash on delivery'),
                          subtitle:
                              const Text('Pay the rider at your door'),
                          value: 'cod',
                        ),
                        RadioListTile<String>(
                          secondary:
                              const Icon(Icons.wallet_outlined),
                          title: const Text('Wallet balance'),
                          subtitle: const Text(
                              'Instant debit from your DDE wallet'),
                          value: 'wallet',
                        ),
                      ],
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
              child: quote.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(apiMessage(e)),
                data: (q) {
                  if (q == null) {
                    return const Text('Cart is empty.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Bill details',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                      const SizedBox(height: 8),
                      _row('Item total', q.subtotal),
                      _row('Coupon discount', -q.discount),
                      _row('Delivery', q.delivery),
                      _row('Taxes', q.tax),
                      const Divider(height: 20),
                      _row('To pay', q.total, bold: true),
                      if (q.discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'You save ${q.discount.toStringAsFixed(2)} on this order',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8),
            ],
          ),
          child: quote.maybeWhen(
            data: (q) => FilledButton(
              onPressed: _busy || q == null ? null : _place,
              child: Text(_busy
                  ? 'Placing…'
                  : 'Place order · ${(q?.total ?? 0).toStringAsFixed(2)}'),
            ),
            orElse: () => FilledButton(
              onPressed: _busy ? null : _place,
              child: Text(_busy ? 'Placing…' : 'Place order'),
            ),
          ),
        ),
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

