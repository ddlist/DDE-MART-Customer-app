# DDE-Mart Customer App

The customer-facing Flutter app for the DDE-Mart platform: food & grocery
ordering, parcels, rentals, rides, home services, dine-in, gifts, wallet
and support — all against one backend API.

- Backend: [DDE-MART-BACKEND](https://github.com/ddlist/DDE-MART-BACKEND) (`master`)
- API reference: `admin-panel/docs/api-v1.md` (Customer sections)

## Features

- **Auth** — register, password login, OTP login, forgot/reset password,
  logout, and self-service **account deletion** (`DELETE /me`, store-review compliant).
- **Home & catalog** — sections, banners, product feeds, store pages,
  product detail with variants/addons, ratings & reviews, favorites.
- **Cart & checkout** — server-priced quotes, coupons, COD / wallet /
  gateway top-up, order tracking with driver position.
- **Verticals** — parcel booking with weight/distance quotes, rentals,
  ride requests, service bookings, dine-in reservations, gift cards.
- **Wallet & referrals** — ledger, top-ups, referral rewards.
- **Safety** — complaints, SOS with GPS, support chat.
- **Platform** — launch gate (min version + maintenance from
  `/app-config`), FCM push per role, dark mode, offline-tolerant UI with
  shimmer loading and empty states.

## Setup

Prerequisites: Flutter 3.41+ (`flutter doctor` clean), Android Studio or
Xcode, and the backend running (see backend README).

```sh
git clone https://github.com/ddlist/DDE-MART-Customer-app.git customer
cd customer
flutter pub get
```

## Run

The API host is not hardcoded — pass it at run time (default:
`http://dde-mart-admin.test/api/v1`):

```sh
# Herd/Valet domain (resolves on this PC):
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# Android emulator when .test doesn't resolve there:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# iOS simulator (same machine as backend):
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1

# Physical phone (same Wi-Fi; backend on 0.0.0.0:8000):
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:8000/api/v1
```

Test accounts: self-register in the app. Demo OTP codes appear in the
backend log outside production (`debug_code`).

## Release build

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
flutter build ipa      --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Push needs `google-services.json` / `GoogleService-Info.plist` per
environment (see `FIREBASE_SETUP.md`) — never committed.

## Verify

```sh
flutter analyze   # clean
flutter test      # 13 tests: cart math, launch gate, nav guards, boot
```

## Support

Installation, tech support, customization: **shariqq.com@gmail.com** ·
WhatsApp **@shareeq9**.

## Credits

Built by [DDLIST](https://ddlist.github.io).

## License

DDLIST Commercial Source License v1.0 � see [LICENSE](LICENSE). You may
use, run, edit, and modify the software for personal or business use,
but you may not resell, redistribute, or republish it.
