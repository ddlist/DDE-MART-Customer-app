// DDE-Mart customer app — reviews (original).
//
// Public approved-review feeds per product/store plus the customer's own
// review inbox. Submitting stays on the order detail (completed orders only).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets.dart';
import '../catalog/catalog_api.dart';

class ReviewsApi {
  ReviewsApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> mine() async {
    final r = await _dio.get('/reviews');
    return (((r.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

final reviewsApiProvider = Provider<ReviewsApi>(
  (ref) => ReviewsApi(ref.watch(dioProvider)),
);

/// One approved review card: stars, comment, author.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = ((review['rating'] as num?) ?? 0).toInt().clamp(0, 5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber[700],
                  ),
                const Spacer(),
                Text(
                  '${review['author_name'] ?? 'Customer'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if ('${review['comment'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${review['comment']}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Public reviews for one product or store.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key, this.productId, this.storeId, this.title});

  final int? productId;
  final int? storeId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Ratings & reviews')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: productId != null
            ? ref.watch(catalogApiProvider).productReviews(productId!)
            : ref.watch(catalogApiProvider).storeReviews(storeId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
              message: 'No reviews yet. Be the first after your order.',
              icon: Icons.star_outline,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final r in rows) ReviewCard(review: r)],
          );
        },
      ),
    );
  }
}

/// Customer's own reviews (mine inbox).
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reviews')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(reviewsApiProvider).mine(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
              message: 'No reviews yet.',
              icon: Icons.star_outline,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in rows)
                Card(
                  child: ListTile(
                    title: Text('Product #${r['product_id']} · ${r['rating']}★'),
                    subtitle: '${r['comment'] ?? ''}'.isEmpty
                        ? null
                        : Text('${r['comment']}'),
                    trailing: Chip(label: Text('${r['status'] ?? ''}')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
