// DDE-Mart customer app — cart state unit tests (original, no backend).

import 'package:dde_customer/features/cart/cart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() => ProviderContainer();

  group('CartStore', () {
    test('add merges identical lines, splits on addons', () {
      final c = container();
      final store = c.read(cartStoreProvider.notifier);

      store.add(productId: 1);
      store.add(productId: 1);
      store.add(productId: 1, addonIds: [7]);

      final state = c.read(cartStoreProvider);
      expect(state.count, 3);
      expect(state.lines.length, 2);
      expect(
        state.lines.firstWhere((l) => l.addonIds.isEmpty).quantity,
        2,
      );
    });

    test('quantity clamps and zero removes', () {
      final c = container();
      final store = c.read(cartStoreProvider.notifier);

      store.add(productId: 2);
      final key = c.read(cartStoreProvider).lines.single.key;

      store.setQuantity(key, 99 + 5);
      expect(c.read(cartStoreProvider).lines.single.quantity, 99);

      store.setQuantity(key, 0);
      expect(c.read(cartStoreProvider).isEmpty, isTrue);
    });

    test('coupon blank clears, clear empties', () {
      final c = container();
      final store = c.read(cartStoreProvider.notifier);

      store.add(productId: 3);
      store.setCoupon('FLAT5');
      expect(c.read(cartStoreProvider).couponCode, 'FLAT5');

      store.setCoupon('   ');
      expect(c.read(cartStoreProvider).couponCode, isNull);

      store.clear();
      expect(c.read(cartStoreProvider).isEmpty, isTrue);
    });

    test('toJson matches the quote API shape', () {
      final c = container();
      final store = c.read(cartStoreProvider.notifier);

      store.add(productId: 5, addonIds: [9]);
      expect(store.toJson(), [
        {'product_id': 5, 'quantity': 1, 'addons': [9]},
      ]);
    });
  });
}
