# Changelog

All notable changes to `codify_p2x_sdk` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) starting at `1.0.0`. Until then, `0.x.y` versions may break compatibility on minor bumps.

## [Unreleased]

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
