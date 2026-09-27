// DDE-Mart customer app — safePush guard tests (original).
//
// Drives navigation the way the app does (SafeNav.safePush): repeat and
// in-stack pushes must never throw Navigator duplicate-key assertions.

// ignore_for_file: avoid_print

import 'package:dde_customer/core/auth_store.dart';
import 'package:dde_customer/core/nav.dart';
import 'package:dde_customer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('repeat and in-stack pushes never crash', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});

    late WidgetRef ref;
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            router = r.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    ref.read(authStoreProvider.notifier).state = const AuthState(
      token: 'test-token',
      name: 'Test',
      phone: '000',
    );
    await tester.pumpAndSettle();

    BuildContext ctx() => tester.element(find.byType(Scaffold).first);

    void dumpPages(String tag) {
      final navs = find.byType(Navigator).evaluate().toList();
      print('NAVS@$tag count=${navs.length}');
      for (final e in navs) {
        final nav = e.widget as Navigator;
        print(
            'PAGES@$tag nav=${nav.key} keys=${nav.pages.map((p) => '${p.key}').toList()}');
      }
    }

    void dumpMatches(String tag) {
      final matches =
          router.routerDelegate.currentConfiguration.matches.toList();
      print('MATCHES@$tag ${matches.map((m) => '${m.runtimeType}:${m.pageKey}').toList()}');
    }

    Future<void> go(String location) async {
      try {
        ctx().safePush(location);
        await tester.pumpAndSettle();
      } catch (_) {
        dumpPages('CRASH-after-$location');
        rethrow;
      }
    }

    await go('/product/1');
    dumpPages('after-product');
    dumpMatches('after-product');
    await go('/cart');
    // Double-tap while stacked.
    await go('/cart');
    await go('/product/1');
    // Revisit after going home.
    await go('/home');
    await go('/cart');
    // Same-pattern different-id chain.
    await go('/store/5');
    await go('/product/2');
    await go('/product/2');
    await go('/checkout');
  });
}
