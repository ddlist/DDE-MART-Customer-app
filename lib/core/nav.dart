// DDE-Mart customer app — navigation guard (original).
//
// GoRouter keys pushed pages by location, so pushing the same location twice
// in quick succession (e.g. double-tapping "Add to cart" or a product card)
// crashes the Navigator with `!keyReservation.contains(key)` and leaves a red
// screen. [SafeNav.safePush] drops repeat pushes of the same location within
// a short window. `go` / `pushReplacement` replace the stack and are unaffected.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

DateTime? _lastPushAt;
String? _lastPushTo;

extension SafeNav on BuildContext {
  /// Push [location], ignoring a repeat push of the same location within
  /// 800ms (almost always an accidental double-tap).
  void safePush(String location, {Object? extra}) {
    final now = DateTime.now();
    if (_lastPushTo == location &&
        _lastPushAt != null &&
        now.difference(_lastPushAt!).inMilliseconds < 800) {
      return;
    }
    _lastPushTo = location;
    _lastPushAt = now;
    push(location, extra: extra);
  }
}
