// DDE-Mart customer app — browse screens (original): categories, stores,
// store menu, product detail with addons, search.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';
import '../cart/cart.dart';
import '../verticals/life.dart';
import 'catalog_api.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = product['id'] as int;
    final price = sellingPrice(product);
    final list = (product['price'] as num?)?.toDouble() ?? price;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => context.safePush('/product/$id'),
        child: Row(
          children: [
            ApiImage(
              path: product['image'] as String?,
              height: 84,
              width: 84,
              icon: Icons.fastfood_outlined,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    PriceText(price: price, was: list > price ? list : null),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                ref.read(cartStoreProvider.notifier).add(productId: id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to cart.')),
                );
              },
            ),
          ],
        ),
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
                    onTap: () => context.safePush(
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
                    onTap: () => context.safePush('/store/${row['id']}'),
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
          final open = (store['is_open'] ?? false) == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Stack(
                children: [
                  ApiImage(
                    path: store['image'] as String?,
                    height: 180,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    icon: Icons.storefront_outlined,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: open ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        open ? 'Open now' : 'Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${store['name']}', style: Theme.of(context).textTheme.headlineSmall),
              if ('${store['address'] ?? ''}'.isNotEmpty)
                Text('${store['address']}', style: Theme.of(context).textTheme.bodySmall),
              if ('${store['description'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${store['description']}'),
                ),
              const SizedBox(height: 12),
              SectionHeader(title: 'Menu', onSeeAll: null),
              for (final p in products) ProductCard(product: p),
              if (products.isEmpty) const EmptyState(message: 'No products in this store.'),
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
  bool _adding = false;

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
          final listPrice = (product['price'] as num?)?.toDouble() ?? 0;
          final salePrice = sellingPrice(product);
          final discountPct = listPrice > salePrice && listPrice > 0
              ? (((listPrice - salePrice) / listPrice) * 100).round()
              : 0;
          final veg = product['veg'];
          final quantity = (product['quantity'] as num?)?.toInt();
          final outOfStock = quantity != null && quantity <= 0;
          final lowStock = quantity != null && quantity > 0 && quantity <= 5;
          final storeId = (product['store_id'] as num?)?.toInt();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Stack(
                children: [
                  ApiImage(
                    path: product['image'] as String?,
                    height: 220,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(16),
                    icon: Icons.fastfood_outlined,
                  ),
                  if (discountPct > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DiscountBadge(label: '-$discountPct%'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('${product['name']}',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (veg is bool) ...[
                    const SizedBox(width: 8),
                    _VegMark(veg: veg),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              PriceText(
                price: salePrice,
                was: listPrice > salePrice ? listPrice : null,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    outOfStock ? Icons.cancel_outlined : Icons.check_circle_outline,
                    size: 16,
                    color: outOfStock
                        ? Theme.of(context).colorScheme.error
                        : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    outOfStock
                        ? 'Out of stock'
                        : lowStock
                            ? 'Only $quantity left'
                            : 'In stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: outOfStock
                              ? Theme.of(context).colorScheme.error
                              : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              if (storeId != null) ...[
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: ref.watch(catalogApiProvider).store(storeId),
                  builder: (context, storeSnapshot) {
                    final name = storeSnapshot.data?['name'];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: Text(name == null ? 'Sold by store #$storeId' : '$name'),
                        subtitle: const Text('View store'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.safePush('/store/$storeId'),
                      ),
                    );
                  },
                ),
              ],
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
                    title: Text('${addon['name']} (+${((addon['price'] as num?) ?? 0).toDouble().toStringAsFixed(2)})'),
                    value: _selectedAddons.contains(addon['id'] as int),
                    onChanged: outOfStock
                        ? null
                        : (value) {
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
                onPressed: outOfStock || _adding
                    ? null
                    : () {
                        setState(() => _adding = true);
                        try {
                          ref.read(cartStoreProvider.notifier).add(
                                productId: widget.productId,
                                addonIds: _selectedAddons.toList(),
                              );
                          context.safePush('/cart');
                        } finally {
                          if (mounted) setState(() => _adding = false);
                        }
                      },
                child: Text(_adding ? 'Adding…' : 'Add to cart'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Indian veg / non-veg mark: green square+dot for veg, red/brown for non-veg.
class _VegMark extends StatelessWidget {
  const _VegMark({required this.veg});

  final bool veg;

  @override
  Widget build(BuildContext context) {
    final color = veg ? Colors.green : const Color(0xFFB3261E);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: veg ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
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
