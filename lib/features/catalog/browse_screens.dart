// DDE-Mart customer app — browse screens (original): categories, stores,
// store menu, product detail with addons, search.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/nav.dart';
import '../../core/widgets.dart';
import '../cart/cart.dart';
import '../reviews/reviews.dart';
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

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, required this.storeId});

  final int storeId;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _search = TextEditingController();
  String _diet = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    try {
      await ref
          .read(lifeApiProvider)
          .favoriteToggle(type: 'store', id: widget.storeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favorite updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(catalogApiProvider);
    final cartCount = ref.watch(cartStoreProvider).count;
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          api.store(widget.storeId),
          api.products(storeId: widget.storeId),
          api.categories(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final store = snapshot.data![0] as Map<String, dynamic>;
          final allProducts = snapshot.data![1] as List<Map<String, dynamic>>;
          final categories = snapshot.data![2] as List<Map<String, dynamic>>;
          final catName = {
            for (final c in categories) (c['id'] as int): '${c['name']}',
          };
          final open = (store['is_open'] ?? false) == true;
          final ratingAvg = (store['rating_avg'] as num?)?.toDouble();
          final ratingCount =
              (store['rating_count'] as num?)?.toInt() ?? 0;
          final deliveryFee =
              ((store['delivery_fee'] as num?) ?? 0).toDouble();
          final minOrder = ((store['min_order'] as num?) ?? 0).toDouble();
          final freeDelivery = (store['self_delivery'] ?? false) == true ||
              deliveryFee <= 0;

          final q = _search.text.trim().toLowerCase();
          final visible = allProducts.where((p) {
            if (_diet == 'veg' && (p['veg'] as bool?) != true) return false;
            if (_diet == 'nonveg' && (p['veg'] as bool?) == true) {
              return false;
            }
            if (q.isNotEmpty &&
                !'${p['name']}'.toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList();
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final p in visible) {
            final key = catName[(p['category_id'] as num?)?.toInt()] ?? 'Menu';
            (groups[key] ??= []).add(p);
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                title: Text('${store['name']}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.favorite_outline),
                    onPressed: _toggleFavorite,
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined),
                        onPressed: () => context.safePush('/cart'),
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      ApiImage(
                        path: store['image'] as String?,
                        width: double.infinity,
                        icon: Icons.storefront_outlined,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
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
                      if (freeDelivery)
                        const Positioned(
                          right: 16,
                          bottom: 12,
                          child: DiscountBadge(label: 'FREE DELIVERY'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${store['name']}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall),
                      if ('${store['address'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${store['address']}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: ratingCount > 0
                            ? () => context.safePush(
                                '/store/${widget.storeId}/reviews')
                            : null,
                        child: StarsRow(
                            avg: ratingAvg, count: ratingCount),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(freeDelivery
                                ? 'Free delivery'
                                : 'Delivery ${deliveryFee.toStringAsFixed(2)}'),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (minOrder > 0)
                            Chip(
                              label: Text(
                                  'Min order ${minOrder.toStringAsFixed(2)}'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      if ('${store['description'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child:
                              Text('${store['description']}'),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Search the menu…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final entry in [
                            ('all', 'All'),
                            ('veg', 'Veg'),
                            ('nonveg', 'Non-veg'),
                          ])
                            ChoiceChip(
                              label: Text(entry.$2),
                              selected: _diet == entry.$1,
                              onSelected: (_) =>
                                  setState(() => _diet = entry.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (visible.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                      message: 'No products match your filters.'),
                )
              else
                for (final group in groups.entries)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(
                            '${group.key} (${group.value.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        children: [
                          for (final p in group.value)
                            ProductCard(product: p),
                        ],
                      ),
                    ),
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          );
        },
      ),
      bottomNavigationBar: cartCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text('View cart · $cartCount item${cartCount == 1 ? '' : 's'}'),
                  onPressed: () => context.safePush('/cart'),
                ),
              ),
            )
          : null,
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
  final _selectedVariants = <int, int>{};
  int _qty = 1;
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
          final variants = ((product['attributes'] as List?) ?? [])
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
          final ratingAvg = (product['rating_avg'] as num?)?.toDouble();
          final ratingCount = (product['rating_count'] as num?)?.toInt() ?? 0;
          final brand = product['brand'] is Map
              ? Map<String, dynamic>.from(product['brand'] as Map)['name']
              : null;
          final nutrition = <String, String>{
            if ('${product['grams'] ?? ''}'.isNotEmpty) 'Weight': '${product['grams']}',
            if ('${product['calories'] ?? ''}'.isNotEmpty)
              'Calories': '${product['calories']}',
            if ('${product['proteins'] ?? ''}'.isNotEmpty)
              'Protein': '${product['proteins']}',
            if ('${product['fats'] ?? ''}'.isNotEmpty) 'Fats': '${product['fats']}',
          };
          var unitTotal = salePrice;
          for (final addon in addons) {
            if (_selectedAddons.contains(addon['id'] as int)) {
              unitTotal += ((addon['price'] as num?) ?? 0).toDouble();
            }
          }
          final grandTotal = unitTotal * _qty;

          return Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Stack(
                  children: [
                    ApiImage(
                      path: product['image'] as String?,
                      height: 240,
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
                      VegMark(veg: veg),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: ratingCount > 0
                      ? () => context.safePush(
                          '/product/${widget.productId}/reviews')
                      : null,
                  child: StarsRow(avg: ratingAvg, count: ratingCount),
                ),
                const SizedBox(height: 6),
                PriceText(
                  price: salePrice,
                  was: listPrice > salePrice ? listPrice : null,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      outOfStock
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
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
                    if (brand != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Brand: $brand',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if ('${product['description'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${product['description']}'),
                  ),
                if (nutrition.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in nutrition.entries)
                        Chip(
                          label: Text('${entry.key}: ${entry.value}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                if (variants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final group in variants) ...[
                    Text(
                      '${group['name'] ?? 'Option'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Required · select any 1',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option
                            in ((group['values'] as List?) ?? []).map((e) =>
                                Map<String, dynamic>.from(e as Map)))
                          ChoiceChip(
                            label: Text('${option['value']}'),
                            selected: (_selectedVariants[
                                        group['attribute_id'] as int] ??
                                    -1) ==
                                (option['id'] as int),
                            onSelected: outOfStock
                                ? null
                                : (_) => setState(() => _selectedVariants[
                                        group['attribute_id'] as int] =
                                    option['id'] as int),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (addons.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Add-ons',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final addon in addons)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${addon['name']} (+${((addon['price'] as num?) ?? 0).toDouble().toStringAsFixed(2)})'),
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
                if (storeId != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, dynamic>>(
                    future: ref.watch(catalogApiProvider).store(storeId),
                    builder: (context, storeSnapshot) {
                      final name = storeSnapshot.data?['name'];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.store_outlined),
                          title: Text(name == null
                              ? 'Sold by store #$storeId'
                              : '$name'),
                          subtitle: const Text('View store'),
                          trailing:
                              const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.safePush('/store/$storeId'),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reviews',
                        style:
                            Theme.of(context).textTheme.titleMedium),
                    if (ratingCount > 0)
                      TextButton(
                        onPressed: () => context.safePush(
                            '/product/${widget.productId}/reviews'),
                        child: const Text('See all'),
                      ),
                  ],
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref
                      .watch(catalogApiProvider)
                      .productReviews(widget.productId),
                  builder: (context, reviewsSnapshot) {
                    if (reviewsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final rows = reviewsSnapshot.data ?? [];
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                            'No reviews yet — order it and be the first to rate.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final r in rows.take(2)) ReviewCard(review: r),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 80),
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
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _qty > 1 && !outOfStock
                                ? () => setState(() => _qty--)
                                : null,
                          ),
                          Text('$_qty',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: !outOfStock && _qty < 99
                                ? () => setState(() => _qty++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: outOfStock || _adding
                            ? null
                            : () {
                                setState(() => _adding = true);
                                try {
                                  final notifier = ref.read(
                                      cartStoreProvider.notifier);
                                  notifier.add(
                                    productId: widget.productId,
                                    addonIds:
                                        _selectedAddons.toList(),
                                  );
                                  final key =
                                      '${widget.productId}:${(List.of(_selectedAddons)..sort()).join(',')}';
                                  if (_qty > 1) {
                                    notifier.setQuantity(key, _qty);
                                  }
                                  context.safePush('/cart');
                                } finally {
                                  if (mounted) {
                                    setState(() => _adding = false);
                                  }
                                }
                              },
                        child: Text(_adding
                            ? 'Adding…'
                            : 'Add item · ${grandTotal.toStringAsFixed(2)}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
