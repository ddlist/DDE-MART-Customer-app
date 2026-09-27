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
  /// Push [location] without ever duplicating a page already in the stack:
  /// GoRouter keys pages by matched location, so pushing a location that is
  /// already stacked (e.g. cart pushed, shell tab switched via `go`, cart
  /// pushed again — or any double-tap) crashes the Navigator with
  /// `!keyReservation.contains(key)`. An in-stack location is reached with
  /// `go` (which rebuilds instead of duplicating); anything else is pushed,
  /// with sub-second repeats of the same location dropped as double-taps.
  void safePush(String location, {Object? extra}) {
    final router = GoRouter.of(this);
    final stacked = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .contains(location);
    if (stacked) {
      go(location);
      return;
    }
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
