// DDE-Mart customer app — CMS pages viewer (original).
//
// Public terms/privacy/help pages from GET /pages + /pages/{slug}.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

class PagesApi {
  PagesApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> pages() async {
    final r = await _dio.get('/pages');
    return (((r.data as Map)['data'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> page(String slug) async {
    final r = await _dio.get('/pages/$slug');
    return Map<String, dynamic>.from((r.data as Map)['data'] as Map);
  }
}

final pagesApiProvider = Provider<PagesApi>(
  (ref) => PagesApi(ref.watch(dioProvider)),
);

class PagesScreen extends ConsumerWidget {
  const PagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & policies')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(pagesApiProvider).pages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) return const Center(child: Text('Nothing here.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['name']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/page/${row['slug']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PageDetailScreen extends ConsumerWidget {
  const PageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.watch(pagesApiProvider).page(slug),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final page = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${page['name'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text('${page['body'] ?? ''}'),
            ],
          );
        },
      ),
    );
  }
}
