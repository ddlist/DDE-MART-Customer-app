// DDE-Mart customer app — home feed (original).
//
// Public catalog endpoints (no token needed): sections, banners, products.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

class HomeFeed {
  HomeFeed({
    required this.sections,
    required this.banners,
    required this.products,
    required this.stories,
  });

  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> stories;
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
  ]);

  return HomeFeed(
    sections: listOf(results[0]),
    banners: listOf(results[1]),
    products: listOf(results[2]),
    stories: listOf(results[3]),
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
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(apiMessage(e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(homeFeedProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (home) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeFeedProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Sections', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in home.sections)
                    ActionChip(
                      label: Text('${s['name']}'),
                      onPressed: () => context.push(
                        '/categories?section=${s['id']}&name=${Uri.encodeComponent('${s['name']}')}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => context.push('/stores'),
                child: const Text('Browse stores'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => context.push('/services'),
                child: const Text('Services: parcel · rental · rides · more'),
              ),
              if (home.stories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Stories', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: home.stories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final story = home.stories[index];
                      final store = story['store'];
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                (story['thumbnail'] as String?)?.isNotEmpty == true
                                    ? NetworkImage(story['thumbnail'] as String)
                                    : null,
                            child: (story['thumbnail'] as String?)?.isNotEmpty == true
                                ? null
                                : const Icon(Icons.play_circle_outline),
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
                ),
              ],
              const SizedBox(height: 16),
              Text('Banners', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final b in home.banners)
                Card(child: ListTile(title: Text('${b['title'] ?? b['name'] ?? ''}'))),
              const SizedBox(height: 16),
              Text('Products', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in home.products)
                Card(
                  child: ListTile(
                    title: Text('${p['name']}'),
                    trailing: Text('${p['price']}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
