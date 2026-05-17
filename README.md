# codify_p2x_sdk

Dart/Flutter SDK for the [Project20X (P2X)](https://api.project20x.com) API. Companion of the TypeScript client at [`@arionhardison/wizard-api-client`](https://github.com/HardisonCo/codify-p2x-sdk) (in renaming).

Used by **Codify Inc.**'s Flutter apps:

- **Codify** — flagship mobile (was Run Tracker)
- **IBD Healthcare** + **IBD Healthcare for Clinicians**
- **PHM** + **PHM Pro**
- **DietManager** — nutrition scanning (was NutriScan)

## Status

**Early — Tier 1 MVP in progress.** Covers the ~20 endpoints NIO needs at launch; Tier 2 (full P2X surface, ~500 endpoints) is codegen-driven once the OpenAPI spec from `api/` lands.

See the canonical plan at [`P2X/FLUTTER_SDK_PLAN.md`](https://github.com/HardisonCo/p2x-monorepo/blob/main/FLUTTER_SDK_PLAN.md) (in the P2X monorepo).

## Install

```yaml
dependencies:
  codify_p2x_sdk:
    git:
      url: https://github.com/HardisonCo/codify-p2x-sdk-dart.git
      ref: main
```

Once published to pub.dev:

```yaml
dependencies:
  codify_p2x_sdk: ^0.1.0
```

## Quick start

```dart
import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';

final p2x = P2xClient(
  config: P2xClientConfig(
    baseUrl: 'https://api.project20x.com/api',
    // Injectable token getter — SDK never touches storage directly.
    getToken: () => myTokenStorage.read(),
    // Injectable subproject resolver — sent as X-Domain on every request.
    getDomain: () => 'nutriscan.codify.ai',
    // Fired once per 401 response. Wire to your logout flow.
    onUnauthorized: () => router.go('/login'),
  ),
);

// Authenticate (NIO: Firebase ID token → Sanctum swap)
final auth = await p2x.auth.firebaseLogin(firebaseIdToken: idToken);
await myTokenStorage.write(auth.token);

// Store a food scan
final scan = await p2x.assessments.storeResponse(
  surveyKey: 'food-intake-daily',
  payload: parsedNutritionJson,
  idempotencyKey: localScanId, // make double-tap-safe
);

// Read subscription state
final order = await p2x.orders.activeSubscription();
print(order.tier); // 'monthly' | 'yearly' | null
```

## Architecture

Mirrors the TS SDK's `BaseApiClient` → per-domain client pattern. Same wire-level contract:

- `Authorization: Bearer <token>` from injected getter
- `X-Domain: <subproject-domain>` on every request
- PUT/PATCH ride POST + `_method=PUT|PATCH` (Laravel convention)
- Multipart with nested arrays (`field[i][nested]=value`) for file uploads
- `ApiResponse<T>` envelope: `{success, message, data, meta?}`
- 401 → `onUnauthorized` callback (SDK never navigates)
- 422 → `ValidationException` with field-keyed `Map<String, List<String>>`
- Idempotency-Key auto-generated for writes (24h server-side TTL via Redis)

```
codify_p2x_sdk
├── lib/
│   ├── codify_p2x_sdk.dart        barrel
│   ├── src/
│   │   ├── client/                P2xClient + interceptors + exceptions
│   │   ├── auth/                  login, firebase-swap, guest-register
│   │   ├── subprojects/           subproject context + features
│   │   ├── wizard/                Five-step wizard
│   │   ├── programs/              Programs + protocols
│   │   ├── modules/               P2X modules: activity, assessments, kpi, …
│   │   ├── integrations/          Per-subproject helpers: nio, mob, ibd, phm
│   │   ├── realtime/              Optional WebSocket/Pusher
│   │   └── utils/                 poll-until, retry policy, form-data builder
└── test/                          flutter_test + http_mock_adapter
```

## Strict TDD

Every endpoint method has a contract test that asserts:

1. The URL
2. The HTTP method
3. The headers (`Authorization`, `X-Domain`, `Idempotency-Key`, `Content-Type`)
4. The request body shape
5. The response decoding

See `test/client/p2x_client_test.dart` for the base-client contract tests.

Run tests:

```bash
flutter test
flutter test --coverage
```

Coverage gates:

| Path | Gate |
|---|---|
| `lib/src/client/**` | ≥85% |
| `lib/src/auth/`, `lib/src/wizard/`, `lib/src/modules/` | ≥75% |
| `lib/src/generated/**` (Tier 2) | excluded |

## Versioning

Tier 1 ships as `0.x.y` (pre-stable). Tier 2 (after codegen lands and the JS SDK reaches `2.x`) ships as `1.x.y`.

Both SDKs (TS + Dart) version-bump in lockstep against the OpenAPI spec in `api/public/docs/api-spec.json`.

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — release notes
- [`CLAUDE.md`](CLAUDE.md) — architecture for contributors
- [`LICENSE`](LICENSE) — license terms
- [`example/`](example) — runnable Flutter example app

## License

Proprietary. See [`LICENSE`](LICENSE). Copyright © 2026 Codify Inc.

## See also

- The TypeScript sibling: [@arionhardison/wizard-api-client](https://github.com/HardisonCo/codify-p2x-sdk) (renaming) — same wire contract, same shape, different host language. Both SDKs version-bump in lockstep against the OpenAPI spec; if you've used one you can navigate the other.
- The API this SDK targets: `P2X/api/` (Laravel 10 monolith on the Codify Inc. droplet)
- Canonical architecture: `P2X/SYSTEM_OVERVIEW.md` in the P2X monorepo
- Launch plan: `P2X/LAUNCH_NOW.md`
