/// ycaas_flutter_sdk — Dart/Flutter client for the YCaaS / P2X API at
/// `https://api.project20x.com`.
///
/// Renamed from `codify_p2x_sdk` at v0.3.0. The `P2x*` type names are kept
/// because they describe the *API contract* (P2X), not the package
/// distribution. See `CLAUDE.md` for the rename rationale.
///
/// Mirrors the architecture and contract of the TypeScript sibling at
/// [@arionhardison/wizard-api-client](https://github.com/HardisonCo/codify-p2x-sdk).
///
/// Quick start:
///
/// ```dart
/// import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';
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
/// // PHM swaps email/password for a Sanctum bearer (no Firebase)
/// final pwd = PasswordSwapClient(p2x);
/// final session2 = await pwd.signIn(login: email, password: pw);
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
library ycaas_flutter_sdk;

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
export 'src/auth/password_swap_client.dart';
export 'src/auth/password_swap_models.dart';
export 'src/auth/token_storage.dart';

// ─── subprojects ────────────────────────────────────────────────────────────
export 'src/subprojects/subprojects_client.dart';
export 'src/subprojects/subprojects_models.dart';

// ─── wizard (YCaaS Five-Step Wizard) ────────────────────────────────────────
export 'src/wizard/wizard_client.dart';
export 'src/wizard/wizard_models.dart';

// ─── utils ──────────────────────────────────────────────────────────────────
export 'src/utils/form_data_builder.dart';
export 'src/utils/poll_until.dart';
export 'src/utils/retry_policy.dart';

// ─── realtime (abstract — bring your own transport) ─────────────────────────
export 'src/realtime/channels.dart';
export 'src/realtime/realtime_client.dart';
export 'src/realtime/realtime_event.dart';

// ─── modules ────────────────────────────────────────────────────────────────
export 'src/modules/activity_client.dart';
export 'src/modules/activity_models.dart';
export 'src/modules/agents_client.dart';
export 'src/modules/application_client.dart';
export 'src/modules/application_models.dart';
export 'src/modules/assessments_client.dart';
export 'src/modules/assessments_models.dart';
export 'src/modules/challenge_client.dart';
export 'src/modules/deals_client.dart';
export 'src/modules/deals_models.dart';
export 'src/modules/disbursement_client.dart';
export 'src/modules/referral_client.dart';
export 'src/modules/report_client.dart';
export 'src/modules/follow_ups_client.dart';
export 'src/modules/follow_ups_models.dart';
export 'src/modules/intake_client.dart';
export 'src/modules/intake_models.dart';
export 'src/modules/items_client.dart';
export 'src/modules/items_models.dart';
export 'src/modules/kpi_client.dart';
export 'src/modules/kpi_models.dart';
export 'src/modules/nudge_client.dart';
export 'src/modules/nudge_models.dart';
export 'src/modules/order_client.dart';
export 'src/modules/order_models.dart';
export 'src/modules/schedule_client.dart';
export 'src/modules/schedule_models.dart';
export 'src/modules/services_client.dart';
export 'src/modules/services_models.dart';
export 'src/modules/verification_client.dart';
export 'src/modules/verification_models.dart';
export 'src/modules/workflow_client.dart';

// ─── voice ───────────────────────────────────────────────────────────────
// Voice agent (utils/voice-agent) — ephemeral SIP credentials for a WebRTC
// call bound to a ProtocolPersonalChain. SIP signaling/audio stays in the app.
export 'src/voice/voice_client.dart';
export 'src/voice/voice_models.dart';

// ─── comms ──────────────────────────────────────────────────────────────────
export 'src/comms/chat_client.dart';
export 'src/comms/chat_models.dart';
export 'src/comms/notification_client.dart';
export 'src/comms/notification_models.dart';

// ─── payment ────────────────────────────────────────────────────────────────
export 'src/payment/payment_client.dart';
export 'src/payment/payment_models.dart';

// ─── integrations ───────────────────────────────────────────────────────────
export 'src/integrations/nio_integrations_client.dart';
export 'src/integrations/nio_integrations_models.dart';
