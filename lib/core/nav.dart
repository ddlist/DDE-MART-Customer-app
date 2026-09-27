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

/// Shell-branch destinations (must stay in sync with the [ShellRoute] in
/// router.dart). Pushing one of these while the shell is already stacked
/// makes GoRouter merge a SECOND shell match into the list, and both shells
/// share one page key — instant `!keyReservation.contains(key)` red screen.
/// They are therefore always reached with [go] (rebuild, never duplicate).
const _shellDestinations = {
  '/home',
  '/search',
  '/pages',
  '/cart',
  '/orders',
  '/wallet',
  '/profile',
};

bool _isShellDestination(String location) {
  if (_shellDestinations.contains(location)) return true;
  return location.startsWith('/page/');
}

extension SafeNav on BuildContext {
  /// Navigate to [location] without ever crashing the Navigator:
  /// shell-branch destinations go via [go] (see [_shellDestinations]),
  /// in-stack locations go via [go], and sub-second repeats of the same
  /// location are dropped as double-taps. Everything else is pushed.
  void safePush(String location, {Object? extra}) {
    if (_isShellDestination(location)) {
      go(location, extra: extra);
      return;
    }
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
