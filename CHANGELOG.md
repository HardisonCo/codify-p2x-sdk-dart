# Changelog

All notable changes to `codify_p2x_sdk` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) starting at `1.0.0`. Until then, `0.x.y` versions may break compatibility on minor bumps.

## [Unreleased]

## [0.2.3] — 2026-05-17

### Fixed

- **First successful OIDC publish.** v0.2.0–v0.2.2 burned through three
  publish-workflow iterations to land the right combo:
  - v0.2.0: Dart-only runner couldn't resolve `flutter: sdk: flutter`.
  - v0.2.1: `subosito/flutter-action@v2` alone — no OIDC config; runner
    fell back to interactive Google OAuth and timed out at 15 min.
  - v0.2.2: added `dart-lang/setup-dart@v1` after flutter-action; OIDC
    request reached pub.dev but pub.dev had no trusted-publisher record.
  - v0.2.3: pub.dev "Automated publishing" enabled on the package admin
    tab pointing at `HardisonCo/codify-p2x-sdk-dart`, tag pattern
    `v{{version}}`, GitHub environment `pub.dev`. Publish succeeds.

No SDK surface changes from v0.2.0/v0.2.1/v0.2.2 — same Tier 1.5 additions.

## [0.2.2] — 2026-05-17

### Fixed

- **Publish workflow** — adds `dart-lang/setup-dart@v1` after `subosito/flutter-action@v2`.
  v0.2.1's publish run still failed because `flutter-action` installs the
  Flutter SDK but does **not** wire pub.dev OIDC into `dart pub publish` —
  the runner fell back to asking for interactive Google OAuth and timed
  out after 15 minutes ("operation was canceled"). `setup-dart@v1` is the
  action that exports the OIDC env vars `dart pub publish` looks for.
  Order matters: flutter-action provides the Flutter SDK for dep
  resolution; setup-dart runs after to overlay OIDC. No SDK surface
  changes from v0.2.0/v0.2.1 — same Tier 1.5 additions.

## [0.2.1] — 2026-05-17

### Fixed

- **Publish workflow** — `.github/workflows/publish.yml` now installs Flutter
  via `subosito/flutter-action@v2` (channel: stable) before `dart pub publish`.
  v0.2.0's publish run failed because the workflow installed Dart only, and
  `dart pub get` fails on a Flutter-depending package with
  `"Flutter users should use 'flutter pub' instead of 'dart pub'."`. No SDK
  surface changes between v0.2.0 and v0.2.1 — same Tier 1.5 additions
  (see v0.2.0 below).
- **CI workflow** — `flutter analyze --fatal-infos` softened to
  `--fatal-warnings`. Info-level lints (mostly `prefer_const_literals_to_create_immutables`
  in test fixtures) no longer fail CI. The lints are still surfaced as
  recommendations.

## [0.2.0] — 2026-05-17

Tier 1.5 — closes the consumer-surface gap so IBD healthcare and PHM apps can ship without dropping to raw Dio. Additive only; no breaking changes to v0.1.x.

### Added

**New module clients (13):**
- `ApplicationClient` — `GET/POST/GET/PUT /api/applications[/{id}]` (IBD doctorRequest, PHM intake apps).
- `VerificationClient` — `GET/POST/GET/PUT /api/verifications[/{id}]` (IBD doctor license uploads).
- `ScheduleClient` — `/api/schedule` + `/api/schedule-call` resource pairs (10 endpoints; IBD appointment slots).
- `ServicesClient` — `resolve`, `slots`, `reserve` (3 endpoints; IBD service lookup + slot reservation).
- `FollowUpsClient` — 6 endpoints incl. `recordVoice` / `finalizeVoice` (IBD post-visit follow-ups).
- `ChatClient` — 10 endpoints under `/api/chat` + `/api/broadcasting/auth` (IBD doctor↔patient messaging, Pusher/Echo presence-channel auth).
- `NotificationClient` — list, unread, delete, startTask (FCM-paired inbox).
- `PaymentClient` — get/save/delete payment method, setup-intent, subscriptions paginator (Stripe).
- `ItemsClient` — items + collections + user-items (12 endpoints; NIO meal plans, PHM care kits).
- `IntakeClient` — `start`, `exchange`, `voiceRecord`, `voiceFinalize`, `submitAnswers`, `setAudience`, `initiateHandoff`, `status` (cross-subproject patient intake handoff).

**Expanded existing clients:**
- `AuthClient` — `signUp`, `resetPassword`, `newPassword`, `finishSocialRegistration` (all unauthenticated via `AuthInterceptor.skipAuthExtra`).
- `OrderClient` — `create`, `update`, `cancel`, `checkout` (Stripe-shaped envelope), `confirm`.
- `NudgeClient` — `checkIn`, `channels`, `snooze`, `destroy`.

**New models:**
- `Application`, `Verification`, `Schedule`, `ScheduleCall`, `Service`, `FollowUp`.
- `ChatRoom`, `ChatMessage`, `PaginatedMessages`, `UserSummary`, `BroadcastAuth`, `AppNotification`.
- `PaymentMethod`, `SetupIntent`, `Subscription`, `PaginatedSubscriptions`.
- `Item`, `Collection`, `UserItem`.
- `Intake`, `IntakeHandoff`, `IntakeStatus`.
- `CheckoutResult`, `NudgeChannel`.

### Tests
- 216 → 529 passing (+313 new).
- All new write methods assert `Idempotency-Key` UUID v4 via `InterceptorsWrapper` capture (no `@visibleForTesting`).
- `PUT/PATCH` → `POST + ?_method=` rewriting verified on every update method.
- ValidationException + NotFoundException + UnauthorizedException paths covered per client.

### Notes
- Tracks `@arionhardison/wizard-api-client` v1.4.0 (TS sibling shipped the same Intake module + 4 cross-cutting routes at the same time).
- Mobile consumer cut: NIO, MOB, IBD, PHM, Codify apps can all drop direct-Dio code in favor of these clients. AdminApiClient / WizardApiClient / ProtocolApiClient surfaces remain deferred (admin/web-only, not mobile-relevant).

## [0.1.1] — TBD

### Changed
- Drop unused codegen deps (`freezed`, `freezed_annotation`, `json_annotation`, `json_serializable`, `build_runner`) from `pubspec.yaml`. They were placeholders for Tier 2 OpenAPI codegen which is not yet shipped, and were causing downstream consumers (e.g. apps using `flutter_stripe ^12.x`) to need `dependency_overrides`. Deps will be re-added when codegen actually lands. See `../P2X/FLUTTER_SDK_PLAN.md`.

### Added
- Initial repo scaffold.
- `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `CLAUDE.md`.
- `lib/codify_p2x_sdk.dart` barrel export.
- Strict-TDD harness — first failing contract test for `P2xClient`.
- CI workflow (lint, analyze, test, dartdoc, pub publish dry-run).
- Publish workflow (pub.dev OIDC on `v*.*.*` tags).
- Example app at `example/`.
- Publish-readiness helper at `tool/check_publish_readiness.sh`.
- Coverage helper at `tool/coverage.sh` (lcov → html, opens on macOS).
- `.gitattributes` enforcing LF line endings.

## [0.1.0] — TBD

Tier 1 MVP. Covers the ~20 endpoints NIO needs at launch and the auth + activity surface MOB v2 will need. Hand-written; codegen-driven Tier 2 lands separately as `1.0.0`.

- `P2xClient` base + injectable token/domain getters.
- `AuthInterceptor`, `SubprojectInterceptor`, `MethodOverrideInterceptor`, `IdempotencyInterceptor`, `ErrorInterceptor`.
- `ApiResponse<T>` envelope + `ApiException` hierarchy (`ValidationException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ServerException`).
- `AuthClient` — login, logout, refresh, me.
- `FirebaseSwapClient` — Firebase ID token → Sanctum (NIO).
- `GuestRegisterClient` — device-bound guest tokens (MOB).
- `AssessmentsClient` — store responses (NIO scans).
- `KpiClient` — daily intake, water, weight, steps.
- `OrderClient` — subscription state read/write.
- `NudgeClient` — active nudges, ack.
- `NioIntegrationsClient` — coins/spend, coins/grant.
- `ActivityClient` (MOB v2) — runs, locations.

[Unreleased]: https://github.com/HardisonCo/codify-p2x-sdk-dart/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/HardisonCo/codify-p2x-sdk-dart/releases/tag/v0.1.0
