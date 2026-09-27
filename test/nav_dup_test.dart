// DDE-Mart customer app — navigation duplicate-key repro (original).
//
// Guest pushes /cart twice (e.g. Add-to-cart double-tap). Must never throw
// the Navigator `!keyReservation.contains(key)` assertion.

import 'package:dde_customer/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guest pushing cart twice does not crash', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});

    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/cart');
    await tester.pumpAndSettle();
    router.push('/cart');
    await tester.pumpAndSettle();
  });
}
