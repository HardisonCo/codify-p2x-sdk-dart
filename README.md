# openyc_flutter_sdk

The **OpenYC Flutter SDK** — Dart/Flutter client for the [OpenYC / P2X](https://api.project20x.com) API at `api.project20x.com`. Companion of the TypeScript client at [`@arionhardison/wizard-api-client`](https://github.com/HardisonCo/codify-p2x-sdk). Codify is the platform; OpenYC is the startup/tech/dev layer on it.

Renamed from `codify_p2x_sdk` at **v0.3.0** and to `openyc_flutter_sdk` at **v0.5.0**. The `P2x*` class names (e.g. `P2xClient`, `P2xClientConfig`) are kept — they name the API contract (P2X), not the package distribution.

Consumed by OpenYC subproject Flutter apps:

- **NutriScan (NIO)** — `nutriscan.codify.ai` (reference implementation)
- **Crohnie AI / IBD Healthcare** — patient + clinician (`crohnie.ai`)
- **PHM Marketplace** — patient + doctor (`phm.ai`)
- *Run Tracker (MOB)* — parked; no backend yet

## Status

**Tier 1 ramp — v0.3.0-alpha.** Covers the auth, wizard, deals, workflow, agents, and core module surfaces needed by the four consumer apps. Tier 2 (full P2X surface, ~500 endpoints, OpenAPI-codegen) lands once `dedoc/scramble` is wired into the API.

See the canonical plan at [`P2X/FLUTTER_SDK_PLAN.md`](https://github.com/HardisonCo/p2x-monorepo/blob/main/FLUTTER_SDK_PLAN.md).

## Install

```yaml
dependencies:
  openyc_flutter_sdk:
    git:
      url: https://github.com/HardisonCo/openyc-flutter-sdk.git
      ref: main
```

Once published to pub.dev:

```yaml
dependencies:
  openyc_flutter_sdk: ^0.5.0
```

### Migrating to `openyc_flutter_sdk`

The package identifier changed at **v0.5.0** (and before that at v0.3.0, from `codify_p2x_sdk`). Whichever earlier name your app depends on, the migration is two mechanical changes:

1. Pubspec dep name: `<old package name>:` → `openyc_flutter_sdk:`.
2. Imports: every `package:<old package name>/...` URI → `package:openyc_flutter_sdk/...` (barrel: `package:openyc_flutter_sdk/openyc_flutter_sdk.dart`). Dart keys `package:` URIs by the pubspec name, so there is no shim at the old barrel path.

No type-name changes — `P2xClient`, `AuthClient`, etc. are unchanged. Find-and-replace + `flutter pub get` is enough.

## Quick start

```dart
import 'package:openyc_flutter_sdk/openyc_flutter_sdk.dart';

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

// Authenticate
// NIO: Firebase ID token → Sanctum swap
final auth = await FirebaseSwapClient(p2x).firebaseLogin(firebaseIdToken: idToken);
// PHM: email/password → Sanctum (no Firebase)
final auth2 = await PasswordSwapClient(p2x).signIn(login: email, password: pw);

// Drive the Five-Step Wizard (OpenYC deal flow)
final wizard = WizardClient(p2x);
final start = await wizard.start(problem: 'Patient needs medication review', metadata: …);
final dealId = start.dealId;
final deals = DealsClient(p2x);
await deals.requiredInfo(dealId: dealId, answers: {…});
await deals.codify(dealId: dealId);
await deals.selectSolution(dealId: dealId, solutionIdx: 0);
await deals.setup(dealId: dealId);
await deals.start(dealId: dealId);

// Persist a food scan (NIO)
await AssessmentsClient(p2x).storeResponse(
  surveyKey: 'food-intake-daily',
  payload: parsedNutritionJson,
  idempotencyKey: localScanId,
);
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
openyc_flutter_sdk
├── lib/
│   ├── openyc_flutter_sdk.dart   barrel
│   ├── src/
│   │   ├── client/               P2xClient + interceptors + exceptions
│   │   ├── auth/                 login, firebase-swap, password-swap, guest-register
│   │   ├── subprojects/          subproject context + features
│   │   ├── wizard/               Five-step wizard (OpenYC deal flow)
│   │   ├── modules/              activity, assessments, deals, workflow, agents, …
│   │   ├── comms/                chat, notifications
│   │   ├── payment/              Stripe payment methods + subscriptions
│   │   ├── integrations/         per-subproject helpers (nio, ibd, phm, mob)
│   │   ├── realtime/             optional Pusher/Echo wrapper (peer-dep)
│   │   └── utils/                poll-until, retry policy, form-data builder
└── test/                         flutter_test + http_mock_adapter
```

## Strict TDD

Every endpoint method has a contract test that asserts:

1. The URL (exact string, including any `_method=` query suffix)
2. The HTTP method (PUT/PATCH expect `POST + _method=`)
3. The headers (`Authorization`, `X-Domain`, `Idempotency-Key`, `Content-Type`)
4. The request body shape
5. The response decoding
6. At least one negative path per write (422) and per auth-required (401)

See `test/client/p2x_client_test.dart` for the base-client contract suite and `CLAUDE.md` for the per-module checklist.

```bash
flutter test
flutter test --coverage
```

Coverage gates (enforced in CI):

| Path | Gate |
|---|---|
| `lib/src/client/**` | ≥85% |
| `lib/src/auth/`, `lib/src/wizard/`, `lib/src/modules/` | ≥75% |
| Overall | ≥70% |

## Versioning

`0.x.y` (current, pre-stable — under pub's caret semantics `^0.4.0` excludes `0.5.0`, so the minor is the breaking slot). `v0.3.0` cut the first package rename + wizard parity; `v0.5.0` cuts the `openyc_flutter_sdk` rename (breaking: dependency key + import URIs). `1.x.y` post-codegen Tier 2.

Both SDKs (TS + Dart) version-bump in lockstep against the OpenAPI spec.

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — release notes
- [`CLAUDE.md`](CLAUDE.md) — architecture + parity matrix + per-app onboarding playbook
- [`example/`](example) — runnable Flutter example app

## License

Proprietary. See [`LICENSE`](LICENSE). Copyright © 2026 Codify Inc.

## See also

- TS sibling: [@arionhardison/wizard-api-client](https://github.com/HardisonCo/codify-p2x-sdk) — same wire contract, different host language.
- API this SDK targets: `P2X/api/` (Laravel 10 monolith).
- Canonical architecture: `P2X/SYSTEM_OVERVIEW.md`.
- OpenYC definition: `docs/PUBLIC_DOMAIN_AGENTS.md` §9.
