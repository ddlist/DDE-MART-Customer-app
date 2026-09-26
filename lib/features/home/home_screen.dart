// DDE-Mart customer app — home feed (original).
//
// Banner carousel, stories rail, category circles, store cards and a
// product grid. Public endpoints (no token): sections, banners, products,
// stories, stores.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../cart/cart.dart';
import '../catalog/catalog_api.dart';

class HomeFeed {
  HomeFeed({
    required this.sections,
    required this.banners,
    required this.products,
    required this.stories,
    required this.stores,
  });

  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stories;
  final List<Map<String, dynamic>> stores;
}

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final dio = ref.watch(dioProvider);

  List<Map<String, dynamic>> listOf(Response r, [String key = 'data']) {
    final data = (r.data as Map)[key];
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  final results = await Future.wait([
    dio.get('/sections'),
    dio.get('/banners'),
    dio.get('/products', queryParameters: {'per_page': 10}),
    dio.get('/stories'),
    dio.get('/stores', queryParameters: {'per_page': 10}),
  ]);

  return HomeFeed(
    sections: listOf(results[0]),
    banners: listOf(results[1]),
    products: listOf(results[2]),
    stories: listOf(results[3]),
    stores: listOf(results[4]),
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DDE-Mart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/cart'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(homeFeedProvider),
        ),
        data: (home) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeFeedProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (home.banners.isNotEmpty) ...[
                _BannerCarousel(banners: home.banners),
                const SizedBox(height: 8),
              ],
              if (home.stories.isNotEmpty)
                _StoriesRail(stories: home.stories),
              _SectionBlock(
                title: 'Shop by category',
                onSeeAll: () => context.push('/categories'),
                child: SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: home.sections.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final section = home.sections[index];
                      return GestureDetector(
                        onTap: () => context.push(
                          '/categories?section=${section['id']}&name=${Uri.encodeComponent('${section['name']}')}',
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                '${section['name']}'.characters.firstOrNull ?? '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '${section['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              _SectionBlock(
                title: 'Stores near you',
                onSeeAll: () => context.push('/stores'),
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: home.stores.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _StoreCard(store: home.stores[index]),
                  ),
                ),
              ),
              _SectionBlock(
                title: 'Popular products',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 250,
                    ),
                    itemCount: home.products.length,
                    itemBuilder: (context, index) =>
                        _ProductCard(product: home.products[index]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.tonal(
                  onPressed: () => context.push('/services'),
                  child: const Text('Services: parcel · rental · rides · more'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.child,
    this.onSeeAll,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: title, onSeeAll: onSeeAll),
          ),
          child,
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<Map<String, dynamic>> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final next = (_page + 1) % widget.banners.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ApiImage(
                  path: banner['image'] as String?,
                  height: 170,
                  borderRadius: BorderRadius.circular(16),
                  icon: Icons.campaign_outlined,
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  Container(
                    width: _page == i ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _page == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StoriesRail extends StatelessWidget {
  const _StoriesRail({required this.stories});

  final List<Map<String, dynamic>> stories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = stories[index];
          final store = story['store'];
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: resolveAsset(story['thumbnail'] as String?) != null
                      ? NetworkImage(resolveAsset(story['thumbnail'] as String?)!)
                      : null,
                  child: resolveAsset(story['thumbnail'] as String?) != null
                      ? null
                      : const Icon(Icons.play_circle_outline),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 64,
                child: Text(
                  '${(store is Map ? store['name'] : null) ?? 'Story'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final Map<String, dynamic> store;

  @override
  Widget build(BuildContext context) {
    final open = (store['is_open'] ?? false) == true;
    return GestureDetector(
      onTap: () => context.push('/store/${store['id']}'),
      child: SizedBox(
        width: 170,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ApiImage(
                    path: store['image'] as String?,
                    height: 110,
                    width: 170,
                    icon: Icons.storefront_outlined,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: open ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        open ? 'Open' : 'Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if ('${store['address'] ?? ''}'.isNotEmpty)
                      Text(
                        '${store['address']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = product['id'] as int;
    final price = sellingPrice(product);
    final list = (product['price'] as num?)?.toDouble() ?? price;

    return GestureDetector(
      onTap: () => context.push('/product/$id'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ApiImage(
                  path: product['image'] as String?,
                  height: 120,
                  width: double.infinity,
                  icon: Icons.fastfood_outlined,
                ),
                if (list > price)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DiscountBadge(
                      label: '-${(((list - price) / list) * 100).round()}%',
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PriceText(price: price, was: list > price ? list : null),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          ref.read(cartStoreProvider.notifier).add(productId: id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart.')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
