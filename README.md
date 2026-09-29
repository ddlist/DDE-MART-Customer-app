# DDE-Mart customer app (clean-room rebuild)

Fresh Flutter app against `admin-panel` API v1 (`docs/api-v1.md`).
No code from the legacy suite — behavior reimplemented from the API contract.

## Run

```sh
# Android emulator (host backend on :8000) or a reachable host:
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# iOS simulator on the same Mac as the backend:
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

## What's wired

- Launch gate: `GET /app-config` (min version per audience + maintenance
  flag, both editable in panel Settings → Mobile apps). Offline fails open;
  each screen retries on its own.
- Auth: register, password login, OTP request/verify, forgot/reset
  password, logout, **account deletion** (`DELETE /me`, store-compliant).
- Home: public sections / banners / products feed with pull-to-refresh.
- Router (`go_router`) guards guests to sign-in and signed-in users home.

## Next (not yet)

- Catalog (category/store/product pages), cart + checkout (COD/wallet +
  gateway redirects via webview), orders + tracking, wallet top-up.
- Verticals: parcel, rental, rides, services, dine-in, gifts, favorites.
- Safety: complaints filing, SOS button, support chat.
- Push: `firebase_messaging` — register token at `POST /push-tokens`,
  subscribe to the `vendors`/`drivers`… (customer app: `customers` topic
  convention TBD) audience topics for order-status broadcasts.
- Firebase native files (`google-services.json` / `GoogleService-Info.plist`)
  are NOT in the repo — add per environment (see backend `.env.example`).

## Verify

```sh
flutter analyze
flutter test
```
