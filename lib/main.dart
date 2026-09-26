// DDE-Mart customer app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeCustomerApp()));
}

class DdeCustomerApp extends ConsumerWidget {
  const DdeCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DDE-Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF059669),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
