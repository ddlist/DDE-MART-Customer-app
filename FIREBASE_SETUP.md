# Firebase setup (all DDE-Mart apps)

Push code is fully wired in `lib/core/push.dart`; only the native config
files are missing (they carry secrets and stay out of git).

## 1. Create the Firebase project(s)

One Firebase project can host all three apps (separate Android apps / iOS
bundle IDs inside it), matching the single backend:

- Android: `com.ddemart.dde_customer`, `com.ddemart.dde_driver`,
  `com.ddemart.dde_vendor`
- iOS: same bundle IDs.

## 2. Drop in the generated files (per app)

- Android: `google-services.json` → `android/app/`
- iOS: `GoogleService-Info.plist` → `ios/Runner/` (add to the Xcode project)

No Dart changes needed — `Firebase.initializeApp()` picks them up, and
`push.dart` skips gracefully when they are absent (screens keep working).

## 3. Backend counterpart (already built)

- `FIREBASE_CREDENTIALS` env (service-account JSON) enables the
  `FcmSender`; without it pushes log as failed and the apps are unaffected.
- Topics: customer app subscribes `customer`, driver `drivers`,
  vendor `vendors`. The admin panel sends order/booking/job broadcasts to
  those topics (see `WorkforceNotifier` + order push listener).
- Token endpoints: `POST /push-tokens` (customer), `POST /driver/push-tokens`,
  `POST /vendor/push-tokens` — called automatically after sign-in.

## 4. Test it

1. `flutter run` the app, sign in (watch logcat for `push:` lines).
2. In the panel, move an order / assign a ride — a notification arrives.
3. Sign out — token is unregistered server-side.
