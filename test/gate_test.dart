// DDE-Mart customer app — launch-gate unit tests (original).

import 'package:dde_customer/core/gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gateStatus', () {
    test('maintenance wins over everything', () {
      expect(
        gateStatus(current: '9.9.9', minimum: '1.0.0', maintenance: true),
        GateDecision.maintenance,
      );
    });

    test('older app requires update', () {
      expect(
        gateStatus(current: '1.0.0', minimum: '1.0.1', maintenance: false),
        GateDecision.updateRequired,
      );
      expect(
        gateStatus(current: '1.9.9', minimum: '2.0.0', maintenance: false),
        GateDecision.updateRequired,
      );
    });

    test('equal or newer app passes', () {
      expect(
        gateStatus(current: '1.0.0', minimum: '1.0.0', maintenance: false),
        GateDecision.ok,
      );
      expect(
        gateStatus(current: '2.3.0', minimum: '2.3', maintenance: false),
        GateDecision.ok,
      );
      expect(
        gateStatus(current: '10.0.0', minimum: '9.9.9', maintenance: false),
        GateDecision.ok,
      );
    });

    test('non-numeric tails are ignored', () {
      expect(
        gateStatus(current: '1.0.0+12', minimum: '1.0.0', maintenance: false),
        GateDecision.ok,
      );
    });
  });
}
