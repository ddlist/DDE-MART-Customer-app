// DDE-Mart customer app — wallet API + screen (original).
//
// GET /wallet (balance in meta + paginated ledger). Top-up starts a gateway
// redirect (POST /wallet/topup → redirect_url, opened in the external
// browser); the verified callback credits the wallet, so the screen tells
// the user to come back and refresh.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';

class WalletData {
  WalletData({required this.balance, required this.entries});

  final double balance;
  final List<Map<String, dynamic>> entries;
}

class WalletApi {
  WalletApi(this._dio);

  final Dio _dio;

  Future<WalletData> wallet() async {
    final response = await _dio.get('/wallet');
    final body = response.data as Map;
    final meta = (body['meta'] as Map?) ?? {};
    final entries = (((body['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList());
    return WalletData(
      balance: ((meta['balance'] as num?) ?? 0).toDouble(),
      entries: entries,
    );
  }

  /// Returns the gateway URL to open for a top-up.
  Future<String> topupUrl({required double amount, required String method}) async {
    final response = await _dio.post('/wallet/topup', data: {
      'amount': amount,
      'method': method,
    });
    final data = (response.data as Map)['data'] as Map;
    return '${data['redirect_url']}';
  }
}

final walletApiProvider = Provider<WalletApi>(
  (ref) => WalletApi(ref.watch(dioProvider)),
);

final walletProvider = FutureProvider<WalletData>((ref) async {
  return ref.watch(walletApiProvider).wallet();
});

const _topupMethods = ['stripe', 'razorpay', 'paypal'];

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with WidgetsBindingObserver {
  final _amount = TextEditingController();
  String _method = _topupMethods.first;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amount.dispose();
    super.dispose();
  }

  /// Returning from the gateway browser re-checks the credited balance.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(walletProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiMessage(e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(walletProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(walletProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data.balance.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text('Top up', style: Theme.of(context).textTheme.titleMedium),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _method,
                items: [
                  for (final m in _topupMethods)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (value) => setState(() => _method = value ?? _topupMethods.first),
                decoration: const InputDecoration(labelText: 'Gateway'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final amount = double.tryParse(_amount.text.trim()) ?? 0;
                        if (amount < 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter an amount of at least 1.')),
                          );
                          return;
                        }
                        setState(() => _busy = true);
                        try {
                          final url = await ref.read(walletApiProvider).topupUrl(
                                amount: amount,
                                method: _method,
                              );
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Complete payment in the browser, then pull to refresh.'),
                              ),
                            );
                          }
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
                child: Text(_busy ? 'Starting…' : 'Top up'),
              ),
              const SizedBox(height: 16),
              Text('Ledger', style: Theme.of(context).textTheme.titleMedium),
              for (final entry in data.entries)
                ListTile(
                  title: Text('${entry['note'] ?? entry['kind']}'),
                  trailing: Text('${entry['amount']}'),
                ),
              if (data.entries.isEmpty) const Text('No activity yet.'),
            ],
          ),
        ),
      ),
    );
  }
}
