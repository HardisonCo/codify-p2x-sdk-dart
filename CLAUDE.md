# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The **YCaaS Flutter SDK** (in-tree package name `ycaas_flutter_sdk`, formerly `codify_p2x_sdk`). The Dart/Flutter client for the P2X API at `https://api.project20x.com`. Companion to the TypeScript SDK at `P2X/sdk/` — same architectural conventions, same envelope, same five-step wizard surface.

For the canonical architectural plan see `P2X/FLUTTER_SDK_PLAN.md`. For the TS sibling we mirror, see `P2X/sdk/CLAUDE.md`. For the API contract, see `P2X/api/CLAUDE.md`.

## What "YCaaS" means

**Y Combinator as a Service** — defined in `P2X/PUBLIC_DOMAIN_AGENTS.md` §9. The autonomous production pipeline that turns domain codification into a repeatable program: spinning up new public-domain agents, custom subdomains (e.g. `riverside-pediatrics.codify.healthcare`), and tier-2/3/4 agents at scale. "Demo day" is when a domain moves from `status: draft` to `status: live` in `gov/`.

The TS SDK already advertises itself as the YCaaS wizard client and is consumed from `https://ycaas.ai`. This Dart SDK is its mobile counterpart. Orthogonal to the DPIaaS/DPCaaS/DPGaaS family — YCaaS is the *automation pipeline*, not a domain service tier.

## P2X ecosystem role

Per the 5-layer model (`P2X/SYSTEM_OVERVIEW.md`):

- **DPIaaS** `gov/` authors policy
- **DPCaaS** `app/` codifies policy into program templates
- **Subprojects** (IBD, PHM, NIO, MOB, …) operate or consume DPGs
- **DPGs** (HRM, LMS, EMR, LIMS) do the work
- **DPG MFEs** (`sys/` + the Flutter apps) are stakeholder dashboards

**This SDK sits between the Flutter apps and `P2X/api`** at `api.project20x.com`. It does **not** talk to product backends (`api.crohnie.ai`, `api.phm.ai`, etc.) — those have their own clients.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter test --coverage                                       # writes coverage/lcov.info
flutter test test/client/p2x_client_test.dart                 # single file
flutter test --plain-name "injects Authorization header"      # filter by name
dart run build_runner build --delete-conflicting-outputs      # after editing freezed / json_serializable
dart run build_runner watch --delete-conflicting-outputs
dart pub publish --dry-run                                    # pre-publish gate
```

## Tech stack

| Layer | Choice |
|---|---|
| Dart SDK | `^3.5.0` floor (lowest common across the six apps) |
| Flutter | `>=3.16.0` |
| HTTP | `dio ^5.7.0` |
| Models | `freezed ^2.5` + `json_serializable ^6.8` |
| Storage | `flutter_secure_storage ^9.2` (tokens) + `shared_preferences ^2.3` (config only) |
| Codegen | `build_runner ^2.4` |
| Tests | `flutter_test` + `http_mock_adapter ^0.6` + `mocktail ^1.0` |
| Lint | `flutter_lints ^5.0` + `very_good_analysis ^6.0` |
| Real-time (peer dep) | `pusher_channels_flutter` — opt-in per app |

## Architecture

### Core principles (mirror the TS SDK)

1. **Injectable token + domain getters.** No global state. Host app provides `getToken: () => String?` and `getDomain: () => String?` to the client config.
2. **PUT/PATCH ride POST + `_method`.** Laravel convention. Handled in `method_override_interceptor.dart`.
3. **`ApiResponse<T>` envelope.** Every method returns `ApiResponse.ok(T data, ApiMeta meta)` or throws `ApiException`. Mirrors `{success, message, data, meta?}` from Laravel.
4. **422 → `ValidationException(Map<String, List<String>>)`.**
5. **401 → callback, not redirect.** Wire `onUnauthorized` to the host's logout flow. The SDK never navigates.
6. **Public endpoints allow `auth: false`.** Per-call opt-out (Stripe webhook, `/api/load`, public auth surface, `personal-chain/join`, `nudge/check/{secret}`).
7. **Idempotency-Key on writes.** Auto-generated UUID v4 per request unless the caller supplies one.

### Pure-Dart vs Flutter boundary

- **Pure Dart** (`lib/src/client/`, `lib/src/auth/auth_client.dart`, models, exceptions): testable with `dart test`; reusable in non-Flutter contexts.
- **Flutter-only** (`flutter_secure_storage`-backed `TokenStorage`, the `realtime/` Pusher wrapper): requires Flutter.

The SDK is published as a Flutter package, but internal callers can mock or replace the Flutter-only pieces.

## Rename: `codify_p2x_sdk` → `ycaas_flutter_sdk`

The rename is in flight as of `0.2.3`. **Until v0.3.0 ships under the new name, both names will coexist** via a barrel re-export. New code should use `ycaas_flutter_sdk` paths; legacy imports continue to work.

### Rename surface (touch list — do not rename ad hoc)

- `pubspec.yaml` — `name:`, `description:`, `repository:`, `homepage:`
- `lib/codify_p2x_sdk.dart` → `lib/ycaas_flutter_sdk.dart` (keep a 1-line shim at the old path that exports the new barrel; remove in v1.0.0)
- All 100+ `import 'package:codify_p2x_sdk/...'` → `import 'package:ycaas_flutter_sdk/...'`
- Class prefix `P2x*` (`P2xClient`, `P2xClientConfig`, `P2xException`, …) **stays as-is** — this names the *API contract* (P2X), not the SDK distribution. Renaming the prefix is gratuitous churn.
- `.github/workflows/{ci,publish}.yml` — `working-directory`, artifact names, publish package name
- `README.md`, `CHANGELOG.md`, this file, fixture filenames, doc comments
- Repo name on GitHub: `codify-p2x-sdk-dart` → `ycaas-flutter-sdk` (do **last**; coordinate with consuming apps' `path:`/`git:` deps)

When in doubt: rename only the *package identifier* and *file paths*, not the *type names* that describe the API contract.

## API parity status

The SDK targets Tier-1 coverage of the P2X Laravel API (`P2X/api`). Current status as of `0.2.3`:

| Module / surface | Status | Notes |
|---|---|---|
| Base client + interceptors (auth, X-Domain, method-override, idempotency, error) | ✅ shipped | Full conformance to spec. ≥85% coverage. |
| Exceptions (401/403/404/422/5xx + base) | ✅ shipped | |
| `auth/` (login, logout, refresh, me, signUp, resetPassword, newPassword, finishSocialRegistration) | ✅ shipped | |
| `auth/firebase_swap_client` (NIO) | ✅ shipped | |
| `auth/guest_register_client` (MOB) | ✅ shipped | |
| `subprojects/` (current, features) | 🟡 partial | Missing: `public/subprojects`, `search`, `me/accessible-subprojects`, `internal/resolve-subproject`. |
| `modules/activity` (logRun, listRuns, appendLocations) | 🟡 partial | API has 26 routes incl. service-location/activity-location. |
| `modules/application` | 🟡 partial | API has 8 routes. |
| `modules/assessments` | 🟡 partial | API has 15 routes incl. question/attend. |
| `modules/follow_ups` (intake, voice, finalize) | ✅ shipped | |
| `modules/items` (items + collections + user items) | ✅ shipped | |
| `modules/kpi` (record + record{Calories,Water,Weight,Steps}) | 🟡 partial | API has 18 incl. user-devices, Withings. |
| `modules/nudge` | ✅ shipped | |
| `modules/order` (incl. checkout, confirm, subscription) | 🟡 partial | API has 22 incl. admin surfaces. |
| `modules/schedule` | ✅ shipped | |
| `modules/services` (resolve, slots, reserve) | ✅ shipped | |
| `modules/verification` | 🟡 partial | API has 8. |
| `comms/chat` | ✅ shipped | |
| `comms/notification` | ✅ shipped | |
| `payment/` (Stripe payment methods, subscriptions) | ✅ shipped | |
| `integrations/nio` (coin balance/spend/grant) | ✅ shipped | |
| **`wizard/`** (Five-Step Wizard, 45+ routes) | ❌ missing | High priority — blocks YCaaS branding alignment with TS SDK. |
| **`modules/deals`** (`wizard/deal/define`, 17 routes) | ❌ missing | High priority. |
| **`modules/workflow`** (`codify-pipeline`, `pipes/invoke`) | ❌ missing | High priority. |
| **`modules/agents`** (24 routes, intelligent intent routing) | ❌ missing | High priority. |
| **`modules/challenge`** (17 routes) | ❌ missing | |
| **`modules/disbursement`** | ❌ missing | Counterpart to `order/`. |
| **`modules/referral`** | ❌ missing | |
| **`modules/report`** | ❌ missing | |
| **`protocols/`** + **`programs/`** (protocol/chain/personal-chain, 90+ routes) | ❌ missing | Large surface. |
| **`integrations/{ibd,phm,mob}`** (m2m batch upsert) | ❌ missing | Server-to-server only; gate behind machine-token ability. |
| **`integrations/codify`** (codify-domain by-tld, public/admin) | ❌ missing | |
| **`realtime/`** (Pusher channels: `user-{id}`, `guest-{id}`, `subproject-{id}-agents`, `codify-ontology`, `pipeline-state-{session}`) | ❌ missing | Peer-dep on `pusher_channels_flutter`. |
| **`utils/`** (`poll_until`, `form_data_builder`, `retry_policy`) | ❌ missing | |

Parity roadmap to **v0.3.0 (YCaaS rename + wizard)**: wizard + deals + workflow + agents + protocols/programs + realtime. Coverage gates apply at the module level — do not merge a new client without its contract suite.

## Consumer apps — adoption matrix

This SDK exists to serve four mobile-app codebases sitting at `../../`. Adoption status drives priority of the parity work.

| App | Path | Adoption | HTTP | State mgmt | Auth | Blocker |
|---|---|---|---|---|---|---|
| **NIO** (NutriScan) | `../../NIO` | ✅ reference impl | Dio | Provider | Firebase → Sanctum swap | None — this is the template |
| **MOB** (Run tracker) | `../../MOB` | ❌ out of scope | none | vanilla | none | App is local-only (Floor ORM); no backend yet |
| **IBD patient** (Crohnie AI) | `../../IBD/crohnie-ai` | ❌ not started | `http` (hand-rolled) | GetX | Firebase Auth → IBD Node backend | GetX coupling; no P2X infra; custom Node auth contract |
| **IBD doctor** (Clinician) | `../../IBD/ibd-doctor` | ❌ not started | `http` (hand-rolled) | GetX | Firebase Auth → IBD Node backend | Same as patient |
| **PHM doctor** (Doctor/Lab/Store) | `../../PHM/doctor` | ❌ not started | Dio + http | Provider | email/pw → PHM Node backend (no Firebase) | No Firebase Auth; custom auth contract |
| **PHM patient** | `../../PHM/patient` | ❌ not started | Dio + http | Provider | email/pw + social → PHM Node | Same as PHM doctor |

### Onboarding playbook (per app)

1. **Add the SDK** to `pubspec.yaml` as `ycaas_flutter_sdk: { path: ../codify-p2x-sdk-dart }` (or git ref) — see `../../NIO/pubspec.yaml` for the canonical line.
2. **Stand up a `P2xService`** modeled on `../../NIO/lib/services/p2x_service.dart`: one `P2xClient` instance, base URL from a compile-time `String.fromEnvironment('P2X_BASE_URL', defaultValue: 'https://api.project20x.com/api')`, `getDomain` returning the app's P2X tenant (e.g. `crohnie.ai`, `phm.ai`).
3. **Pick the auth strategy:**
   - Firebase-backed apps (NIO, IBD patient, IBD doctor) → `FirebaseSwapClient.firebaseLogin(idToken)`.
   - Non-Firebase apps (PHM patient, PHM doctor) → either provision Firebase Auth on those apps, or extend the SDK with a `password_swap_client.dart` that exchanges email/pw for a Sanctum token via `POST /public/auth/sign-in`. **Default to extending the SDK** — it's a smaller change than retrofitting Firebase across PHM, and it's mirrored on the TS side.
4. **Wire `onUnauthorized`** to the host app's logout flow.
5. **Replace ad-hoc HTTP calls feature-by-feature**, not in one go. Track adoption with `// TODO(ycaas): migrate to <client>` comments so progress is greppable.
6. **Per-app integration test suite** lives in `test/integrations/<app>/` in this repo (not in the consumer app) — assert that the SDK exposes everything the app needs.

**MOB is parked.** It has no backend today. Revisit when MOB's roadmap includes server-side run sync; the `guest_register_client` is already shipped for when that day comes.

**IBD apps will fight GetX.** Plan for a `P2xService` wrapper class that GetX controllers depend on, so the SDK itself stays state-management-agnostic. Do **not** add GetX bindings inside the SDK.

## Strict TDD — workflow for adding a new module client

Every endpoint method gets a **contract test before the method**. Red → green → refactor.

The test asserts (using `http_mock_adapter`):

1. URL (exact string, including any `_method=` query suffix)
2. HTTP method (GET / POST / DELETE; PUT/PATCH expect `POST` + `_method=put|patch`)
3. Required headers (`Authorization: Bearer …`, `X-Domain: …`, `Idempotency-Key: …`, `Content-Type: …`)
4. Request body shape (for POST/PUT/PATCH)
5. Response decoding into the freezed model
6. **Negative path** — at least one 422 test per write endpoint, and one 401 test per auth-required endpoint. Confirms `ValidationException` shape and `onUnauthorized` callback fires.

### Checklist for a new `modules/<thing>_client.dart`

- [ ] Skim `P2X/api/routes/api.php` and any `Modules/<Thing>/Routes/api.php` — list every route, method, middleware, and request body
- [ ] Write `test/modules/<thing>_client_test.dart` with the contract assertions above, **before** the client file
- [ ] Write `test/modules/<thing>_models_test.dart` with round-trip JSON tests for each model
- [ ] Add freezed models in `lib/src/modules/<thing>/<thing>_models.dart`, run codegen
- [ ] Implement the client to make tests pass — one method per route, named to match the route action (`list`, `create`, `get`, `update`, `destroy`, plus domain verbs)
- [ ] Export from `lib/codify_p2x_sdk.dart` (and the new `lib/ycaas_flutter_sdk.dart` barrel)
- [ ] Cover gate: ≥75% lines on the new file. Generated `*.g.dart` / `*.freezed.dart` is excluded.
- [ ] Update the **API parity status** table above and add a CHANGELOG entry

### Test layout convention

```
test/
├── client/
│   ├── p2x_client_test.dart
│   └── interceptors/
│       ├── auth_interceptor_test.dart
│       ├── subproject_interceptor_test.dart
│       └── …
├── auth/
├── modules/
│   ├── <thing>_client_test.dart
│   └── <thing>_models_test.dart
├── fixtures/                                JSON response fixtures keyed by route
└── mocks/
```

### Coverage gates (enforced in CI)

| Path | Gate |
|---|---|
| `lib/src/client/**` | ≥85% lines/branches |
| `lib/src/auth/**`, `lib/src/wizard/**`, `lib/src/modules/**` | ≥75% |
| Generated code (`*.g.dart`, `*.freezed.dart`, `lib/src/generated/`) | excluded |
| Overall | ≥70% |

PRs below the gate fail.

## Versioning

- `0.x.y` (current) — pre-stable Tier 1. Breaking changes do not bump major.
- `v0.3.0` cuts the YCaaS rename + Five-Step Wizard parity.
- `1.x.y` post-codegen Tier 2 (OpenAPI-driven via `dedoc/scramble`). Semver from there.
- Dart and TS SDKs version-bump in lockstep against the OpenAPI spec.

## Publishing to pub.dev

```bash
dart pub publish --dry-run     # gate
dart pub publish               # only after CI green, coverage green, CHANGELOG updated
```

The publish workflow `.github/workflows/publish.yml` triggers on tag `v*.*.*`. Auth via pub.dev OIDC (no static token). First successful OIDC publish landed at `v0.2.3`.

## Don't-do list

- **Don't talk to product backends** (`api.crohnie.ai`, `api.phm.ai`, etc.) from this SDK. Only `api.project20x.com`. IBD/PHM apps that need their *own* backends keep their *own* clients.
- **Don't store the token via `SharedPreferences`** — always `flutter_secure_storage`. Bearer tokens are password-equivalent.
- **Don't navigate from the SDK.** 401 fires `onUnauthorized`; the host app navigates.
- **Don't add `dart:html` or browser-only imports.** iOS + Android first; Flutter Web is not a launch target.
- **Don't put real API base URLs in SDK constants.** Always inject via `P2xClientConfig.baseUrl`.
- **Don't import Flutter widgets** in `lib/src/client/`. The base client stays testable in pure Dart.
- **Don't add new transitive dependencies** without bumping the Dart SDK floor only if strictly required — keep it at `^3.5.0`.
- **Don't reach for a state-management library** (Riverpod, BLoC, Provider, GetX). The SDK is a pure client; state belongs to the host app.
- **Don't rename `P2x*` type names** during the YCaaS package rename. They name the API contract (P2X), not the distribution.
- **Don't ship a new module client without its contract suite.** TDD is enforced by the coverage gate and by review.

## Cross-references

- Canonical plan: `P2X/FLUTTER_SDK_PLAN.md`
- TS sibling: `P2X/sdk/CLAUDE.md`
- API contract: `P2X/api/CLAUDE.md`
- Architecture: `P2X/SYSTEM_OVERVIEW.md`
- YCaaS definition: `P2X/PUBLIC_DOMAIN_AGENTS.md` §9
- Subproject integration model: `P2X/SUBPROJECT_INTEGRATION_PLAN.md`
- NIO reference implementation: `../../NIO/lib/services/p2x_service.dart`
