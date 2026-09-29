// DDE-Mart customer app — tolerant API id parsing (original test).

import 'package:dde_customer/features/verticals/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('idAsInt', () {
    test('passes ints through', () => expect(idAsInt(7), 7));
    test('parses numeric strings', () => expect(idAsInt('42'), 42));
    test('null and garbage degrade to null', () {
      expect(idAsInt(null), isNull);
      expect(idAsInt('abc'), isNull);
      expect(idAsInt(3.5), isNull);
    });
  });
}
