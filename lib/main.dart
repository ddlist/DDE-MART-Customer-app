// DDE-Mart customer app — entry point (original, clean-room rebuild).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: DdeCustomerApp()));
}

class DdeCustomerApp extends ConsumerWidget {
  const DdeCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Instantiates the session watcher; syncs push once per sign-in.
    ref.watch(pushSyncProvider);

    return MaterialApp.router(
      title: 'DDE-Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF059669),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF059669),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
