// DDE-Mart customer app — smoke test (original).
//
// Boots the real app: with no backend reachable the gate fails open and the
// router sends guests to sign-in.

import 'package:dde_customer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to the sign-in screen offline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DdeCustomerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
