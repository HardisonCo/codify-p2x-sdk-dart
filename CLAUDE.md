# CLAUDE.md — codify-p2x-sdk-dart

This file is for Claude Code working **inside** this repo. The Dart/Flutter SDK that all six Codify Inc. mobile apps consume.

For the canonical architectural plan see `P2X/FLUTTER_SDK_PLAN.md` in the P2X monorepo. For the TS sibling whose conventions we mirror see `P2X/sdk/CLAUDE.md`.

## What this is

The Dart/Flutter SDK for the P2X API at `https://api.project20x.com`. Companion to the TypeScript client at [@arionhardison/wizard-api-client](https://github.com/HardisonCo/codify-p2x-sdk) (in renaming). One SDK that **all six** Codify Inc. Flutter apps (Codify, IBD Healthcare, IBD Healthcare for Clinicians, PHM, PHM Pro, DietManager) eventually consume.

Tier 1 (current) is hand-written, ~20 endpoints, focused on NIO's launch needs. Tier 2 (post-launch) is codegen-driven against an OpenAPI spec produced from Laravel via `dedoc/scramble`.

## P2X ecosystem role

Per the 5-layer model (see `P2X/SYSTEM_OVERVIEW.md`):

- **DPIaaS** `gov/` authors policy
- **DPCaaS** `app/` codifies policy into program templates
- **Subprojects** (DOH-NY, Codify, etc.) operate or consume DPGs
- **DPGs** (HRM, LMS, EMR, LIMS, plus IBD/PHM/NIO/MOB) do the work
- **DPG MFEs** (`sys/`, the six Flutter apps) are stakeholder dashboards

**This SDK sits between the Flutter apps and `P2X/api`.** It does not talk to product backends (`api.ibd.healthcare`, `api.phm.ai`) — those have their own clients. It only talks to `api.project20x.com`.

## Commands

```bash
# Get deps
flutter pub get

# Lint
flutter analyze

# Run all tests
flutter test

# Coverage
flutter test --coverage
# Open: open coverage/html/index.html  (after `lcov -> html` step in tool/coverage.sh)

# Single test file
flutter test test/client/p2x_client_test.dart

# Filter by test name
flutter test --plain-name "injects Authorization header"

# Codegen (after editing freezed / json_serializable annotations)
dart run build_runner build --delete-conflicting-outputs

# Codegen watcher
dart run build_runner watch --delete-conflicting-outputs
```

## Tech stack

| Layer | Choice |
|---|---|
| Dart SDK | `^3.5.0` (lowest common across the 6 apps; **MOB must bump from 3.0 → 3.5 to consume**) |
| Flutter | `>=3.16.0` |
| HTTP | `dio ^5.7.0` |
| Models | `freezed ^2.5` + `json_serializable ^6.8` |
| Storage | `flutter_secure_storage ^9.2` (tokens) + `shared_preferences ^2.3` (config) |
| Codegen | `build_runner ^2.4` |
| Tests | `flutter_test` + `http_mock_adapter ^0.6` + `mocktail ^1.0` |
| Lint | `flutter_lints ^5.0` + `very_good_analysis ^6.0` |
| Real-time (peer dep) | `pusher_channels_flutter` — opt-in per app |

## Architecture

### Core principles (inherited from the TS SDK)

1. **Injectable token + domain getters.** No global state. Host app provides `getToken: () => String?` and `getDomain: () => String?` to `P2xClientConfig`.
2. **PUT/PATCH ride POST + `_method`.** Laravel convention. Handled in `method_override_interceptor.dart`.
3. **`ApiResponse<T>` envelope.** Every method returns either an `ApiResponse.ok(T data, ApiMeta meta)` or throws `ApiException`. Mirrors `{success, message, data, meta?}` from Laravel.
4. **422 → `ValidationException(Map<String, List<String>>)`.**
5. **401 → callback, not redirect.** Wire `onUnauthorized` to your logout flow.
6. **Public endpoints allow `auth: false`.** Per-call opt-out (Stripe webhook, `/api/load`, public auth surface).
7. **Idempotency-Key on writes.** Auto-generated UUID per request unless caller supplies one.

### Module layout

```
lib/
├── codify_p2x_sdk.dart                       barrel export
├── src/
│   ├── client/
│   │   ├── p2x_client.dart                   the BaseApiClient equivalent
│   │   ├── p2x_client_config.dart            ApiClientConfig — injectable getters
│   │   ├── api_response.dart                 ApiResponse<T> + ApiMeta (freezed)
│   │   ├── interceptors/
│   │   │   ├── auth_interceptor.dart         Bearer injection
│   │   │   ├── subproject_interceptor.dart   X-Domain injection
│   │   │   ├── method_override_interceptor.dart  PUT/PATCH → POST + _method
│   │   │   ├── idempotency_interceptor.dart  Idempotency-Key for writes
│   │   │   └── error_interceptor.dart        ApiException normalization
│   │   └── exceptions/
│   │       ├── api_exception.dart            base class
│   │       ├── validation_exception.dart     422
│   │       ├── unauthorized_exception.dart   401
│   │       ├── forbidden_exception.dart      403
│   │       ├── not_found_exception.dart      404
│   │       └── server_exception.dart         5xx
│   ├── auth/
│   │   ├── auth_client.dart                  login, logout, refresh, me
│   │   ├── firebase_swap_client.dart         Firebase ID token → Sanctum
│   │   ├── guest_register_client.dart        device-bound guest tokens (MOB)
│   │   └── auth_models.dart
│   ├── subprojects/
│   ├── wizard/                               5-step wizard
│   ├── programs/
│   ├── protocols/
│   ├── modules/                              one client per P2X module
│   │   ├── activity_client.dart
│   │   ├── assessments_client.dart
│   │   ├── kpi_client.dart
│   │   ├── nudge_client.dart
│   │   ├── order_client.dart
│   │   ├── disbursement_client.dart
│   │   └── …
│   ├── integrations/                         per-subproject helpers
│   │   ├── nio_integrations_client.dart
│   │   ├── mob_integrations_client.dart
│   │   ├── ibd_integrations_client.dart      (Tier 2)
│   │   └── phm_integrations_client.dart      (Tier 2)
│   ├── realtime/                             optional Pusher/Echo wrapper
│   └── utils/
│       ├── poll_until.dart
│       ├── form_data_builder.dart
│       └── retry_policy.dart
test/
├── client/
├── auth/
├── modules/
├── fixtures/                                 JSON response fixtures
└── mocks/
```

### Pure-Dart vs Flutter boundary

- **Pure Dart** (`lib/src/client/`, `lib/src/auth/auth_client.dart`, models, exceptions): testable with `dart test`; reusable in non-Flutter contexts.
- **Flutter-only** (`lib/src/auth/token_storage.dart` via flutter_secure_storage, `lib/src/realtime/` via pusher_channels_flutter): requires Flutter context.

The SDK is published as a Flutter package (the easiest distribution), but internal callers can mock or replace the Flutter-only pieces.

## Strict TDD

Every endpoint method gets a contract test **before** the method. Red → green → refactor.

The test asserts (using `http_mock_adapter`):

1. URL (exact string)
2. HTTP method (GET / POST / etc.; PUT/PATCH expect POST + `_method=`)
3. Required headers (`Authorization: Bearer …`, `X-Domain: …`, `Idempotency-Key: …`, `Content-Type: …`)
4. Request body shape (for POST/PUT/PATCH)
5. Response decoding into the freezed model

See `test/client/p2x_client_test.dart` for the base-client contract suite.

### Test layout convention

```
test/
├── client/
│   └── p2x_client_test.dart
├── client/interceptors/
│   ├── auth_interceptor_test.dart
│   ├── subproject_interceptor_test.dart
│   └── …
├── auth/
│   ├── auth_client_test.dart
│   ├── firebase_swap_client_test.dart
│   └── guest_register_client_test.dart
└── modules/
    ├── activity_client_test.dart
    ├── assessments_client_test.dart
    └── …
```

### Coverage gates

| Path | Gate |
|---|---|
| `lib/src/client/**` | ≥85% lines/branches |
| `lib/src/auth/**`, `lib/src/wizard/**`, `lib/src/modules/**` | ≥75% |
| Generated code (`*.g.dart`, `*.freezed.dart`, `lib/src/generated/`) | excluded |
| Overall | ≥70% |

CI fails PRs below the gate.

## Versioning

- Tier 1 ships as `0.x.y` (pre-stable). Breaking changes don't bump major.
- Tier 2 (post-codegen) ships as `1.x.y`. Semver from there.
- Both SDKs (TS + Dart) version-bump in lockstep against the OpenAPI spec.

## Publishing to pub.dev

Tier 1 publishes on the first stable cut once NIO is live.

```bash
# Pre-publish gate
dart pub publish --dry-run

# Publish (only after CI green, coverage gate green, CHANGELOG.md updated)
dart pub publish
```

The publish workflow is `.github/workflows/publish.yml`. Triggered on tag `v*.*.*`. Auth via `PUB_DEV_PUBLISH_ACCESS_TOKEN` GitHub secret (OIDC flow preferred; static token fallback).

## Don't-do list

- **Don't talk to product backends** (`api.ibd.healthcare`, `api.phm.ai`, etc.) from this SDK. The SDK only talks to `api.project20x.com`. IBD/PHM Flutter apps have their own clients.
- **Don't store the token via `SharedPreferences`** — always use `flutter_secure_storage`. Bearer tokens are password-equivalent.
- **Don't navigate from the SDK.** 401 fires the `onUnauthorized` callback; the host app navigates.
- **Don't add `dart:html` or browser-only imports.** The SDK must work on iOS + Android (and eventually Flutter Web, though not a launch target).
- **Don't put real API base URLs in the SDK constants.** Always inject via `P2xClientConfig.baseUrl`.
- **Don't import Flutter widgets** in `lib/src/client/`. The base client should be testable in pure Dart.
- **Don't add new transitive dependencies** without bumping the `pubspec.yaml`'s `min Dart SDK` if needed — keep the floor at `^3.5.0`.
- **Don't reach for a state-management library** (Riverpod, BLoC, Provider). The SDK is a pure client; state belongs to the host app.

## Cross-references

- Canonical plan: [`P2X/FLUTTER_SDK_PLAN.md`](https://github.com/HardisonCo/p2x-monorepo)
- TS sibling: [`P2X/sdk/CLAUDE.md`](https://github.com/HardisonCo/codify-p2x-sdk)
- API contract: `P2X/api/CLAUDE.md`
- Architecture: `P2X/SYSTEM_OVERVIEW.md`
- Launch context: `P2X/LAUNCH_NOW.md`
