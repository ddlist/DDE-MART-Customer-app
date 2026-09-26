// DDE-Mart customer app — browse screens (original): categories, stores,
// store menu, product detail with addons, search.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../cart/cart.dart';
import '../verticals/life.dart';
import 'catalog_api.dart';

String _money(num value) => value.toDouble().toStringAsFixed(2);

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = product['id'] as int;
    return Card(
      child: ListTile(
        title: Text('${product['name']}'),
        subtitle: Text(_money(sellingPrice(product))),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart_outlined),
          onPressed: () {
            ref.read(cartStoreProvider.notifier).add(productId: id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added to cart.')),
            );
          },
        ),
        onTap: () => context.push('/product/$id'),
      ),
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key, this.sectionId, this.sectionName});

  final int? sectionId;
  final String? sectionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(sectionName ?? 'Categories')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(catalogApiProvider).categories(sectionId: sectionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('Nothing here yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['name']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/category/${row['id']}?name=${Uri.encodeComponent('${row['name']}')}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({super.key, required this.categoryId, this.name});

  final int categoryId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Products')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(catalogApiProvider).products(categoryId: categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('No products.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final p in rows) ProductCard(product: p)],
          );
        },
      ),
    );
  }
}

class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(catalogApiProvider).stores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('No stores.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['name']}'),
                    subtitle: Text((row['is_open'] ?? false) == true ? 'Open' : 'Closed'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/store/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key, required this.storeId});

  final int storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(catalogApiProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            onPressed: () async {
              try {
                await ref.read(lifeApiProvider).favoriteToggle(type: 'store', id: storeId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Favorite updated.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(apiMessage(e))),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([api.store(storeId), api.products(storeId: storeId)]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final store = snapshot.data![0] as Map<String, dynamic>;
          final products = snapshot.data![1] as List<Map<String, dynamic>>;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${store['name']}', style: Theme.of(context).textTheme.headlineSmall),
              if ('${store['description'] ?? ''}'.isNotEmpty)
                Text('${store['description']}'),
              const SizedBox(height: 12),
              for (final p in products) ProductCard(product: p),
              if (products.isEmpty) const Text('No products in this store.'),
            ],
          );
        },
      ),
    );
  }
}

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final _selectedAddons = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            onPressed: () async {
              try {
                await ref.read(lifeApiProvider).favoriteToggle(
                      type: 'product',
                      id: widget.productId,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Favorite updated.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(apiMessage(e))),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(catalogApiProvider).product(widget.productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final product = snapshot.data!;
          final addons = ((product['addons'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${product['name']}', style: Theme.of(context).textTheme.headlineSmall),
              Text(
                _money(sellingPrice(product)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if ('${product['description'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${product['description']}'),
                ),
              if (addons.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Extras', style: Theme.of(context).textTheme.titleMedium),
                for (final addon in addons)
                  CheckboxListTile(
                    title: Text('${addon['name']} (+${_money((addon['price'] as num?) ?? 0)})'),
                    value: _selectedAddons.contains(addon['id'] as int),
                    onChanged: (value) {
                      setState(() {
                        final id = addon['id'] as int;
                        if (value == true) {
                          _selectedAddons.add(id);
                        } else {
                          _selectedAddons.remove(id);
                        }
                      });
                    },
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(cartStoreProvider.notifier).add(
                        productId: widget.productId,
                        addonIds: _selectedAddons.toList(),
                      );
                  context.push('/cart');
                },
                child: const Text('Add to cart'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      _results = await ref.read(catalogApiProvider).products(q: _query.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Search products',
              suffixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          for (final p in _results) ProductCard(product: p),
        ],
      ),
    );
  }
}
