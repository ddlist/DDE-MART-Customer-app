// DDE-Mart customer app — smoke test (original).
//
// Boots the real app: with no backend reachable the gate fails open, the
// saved onboarding flag skips onboarding, and the router sends guests to
// sign-in.

import 'package:dde_customer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('boots to the sign-in screen offline', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.done': true});

    await tester.pumpWidget(const ProviderScope(child: DdeCustomerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
