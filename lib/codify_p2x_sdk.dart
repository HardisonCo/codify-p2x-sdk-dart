/// codify_p2x_sdk — Dart/Flutter client for the Project20X (P2X) API.
///
/// Mirrors the architecture and contract of the TypeScript sibling at
/// [@arionhardison/wizard-api-client](https://github.com/HardisonCo/codify-p2x-sdk).
///
/// Quick start:
///
/// ```dart
/// import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
///
/// final p2x = P2xClient(
///   config: P2xClientConfig(
///     baseUrl: 'https://api.project20x.com/api',
///     getToken: () => tokenStorage.read(),
///     getDomain: () => 'nutriscan.codify.ai',
///     onUnauthorized: () => router.go('/login'),
///   ),
/// );
///
/// // Auth — NIO swaps a Firebase ID token for a Sanctum bearer
/// final auth = FirebaseSwapClient(p2x);
/// final session = await auth.firebaseLogin(firebaseIdToken: idToken);
///
/// // Persist a food scan
/// final assessments = AssessmentsClient(p2x);
/// final scan = await assessments.storeResponse(
///   surveyKey: 'food-intake-daily',
///   payload: parsedNutritionJson,
///   idempotencyKey: localScanId,
/// );
/// ```
///
/// See `README.md` for the full surface and `CLAUDE.md` for contributor
/// notes. Typed errors (UnauthorizedException, ValidationException, etc.) are
/// thrown directly from per-domain client methods — see the `request` helper
/// on `P2xClient` for the unwrap mechanics.
library codify_p2x_sdk;

// ─── client ─────────────────────────────────────────────────────────────────
export 'src/client/api_response.dart';
export 'src/client/p2x_client.dart';
export 'src/client/p2x_client_config.dart';

// ─── exceptions ─────────────────────────────────────────────────────────────
export 'src/client/exceptions/api_exception.dart';
export 'src/client/exceptions/forbidden_exception.dart';
export 'src/client/exceptions/not_found_exception.dart';
export 'src/client/exceptions/server_exception.dart';
export 'src/client/exceptions/unauthorized_exception.dart';
export 'src/client/exceptions/validation_exception.dart';

// ─── auth ───────────────────────────────────────────────────────────────────
export 'src/auth/auth_client.dart';
export 'src/auth/auth_models.dart';
export 'src/auth/firebase_swap_client.dart';
export 'src/auth/guest_register_client.dart';
export 'src/auth/token_storage.dart';

// ─── subprojects ────────────────────────────────────────────────────────────
export 'src/subprojects/subprojects_client.dart';
export 'src/subprojects/subprojects_models.dart';

// ─── modules ────────────────────────────────────────────────────────────────
export 'src/modules/activity_client.dart';
export 'src/modules/activity_models.dart';
export 'src/modules/assessments_client.dart';
export 'src/modules/assessments_models.dart';
export 'src/modules/kpi_client.dart';
export 'src/modules/kpi_models.dart';
export 'src/modules/nudge_client.dart';
export 'src/modules/nudge_models.dart';
export 'src/modules/order_client.dart';
export 'src/modules/order_models.dart';

// ─── integrations ───────────────────────────────────────────────────────────
export 'src/integrations/nio_integrations_client.dart';
export 'src/integrations/nio_integrations_models.dart';
