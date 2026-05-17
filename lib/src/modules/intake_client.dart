import 'package:dio/dio.dart';

import 'package:codify_p2x_sdk/src/client/interceptors/auth_interceptor.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/modules/intake_models.dart';

/// Per-domain client for the **Intake** module.
///
/// Eight endpoints powering the cross-subproject guest intake flow
/// (mirrors the TS sibling `IntakeModuleApiClient` shipped in
/// `@codify/p2x-sdk` v1.4.0):
///
///   * `POST /api/v1/intake/start`                              — kick off a guest intake
///   * `POST /api/v1/intake/handoff/{token}/exchange`           — public — receive a handoff
///   * `POST /api/v1/intake/{intake}/voice-record`              — attach a recorded chunk
///   * `POST /api/v1/intake/{intake}/voice-finalize`            — finalise recording
///   * `POST /api/v1/intake/{intake}/answers`                   — replace structured answers
///   * `POST /api/v1/intake/{intake}/audience`                  — set audience tier
///   * `POST /api/v1/intake/{intake}/handoff`                   — mint a handoff token
///   * `GET  /api/v1/intake/{intake}/status`                    — lightweight poll
///
/// Auth model:
///   * `start()` is authenticated under the SDK's Bearer token (the
///     calling subproject identifies itself; the server creates a
///     guest user under that subproject).
///   * `exchange()` is **unauthenticated** — the handoff token IS the
///     credential, so the SDK skips Bearer injection on that single
///     call via [AuthInterceptor.skipAuthExtra].
///   * Everything else under `/{intake}/*` requires the SDK's Bearer.
///
/// All POSTs auto-receive a fresh UUID v4 `Idempotency-Key` from the
/// SDK's interceptor stack so retries across network blips are safe.
class IntakeClient {
  /// Construct with a reference to the shared [P2xClient].
  IntakeClient(this._client);

  final P2xClient _client;

  /// `POST /api/v1/intake/start` — kick off a guest intake session.
  ///
  /// The server creates a fresh intake row (status `'open'`) under the
  /// active subproject and returns it. Caller-side retries are safe —
  /// the SDK auto-attaches a fresh UUID v4 `Idempotency-Key` so the
  /// upstream `idempotency` middleware (Redis, 24h TTL) collapses
  /// duplicates server-side.
  ///
  /// [audienceHint] / [metadata] are open-shape fields forwarded to the
  /// server verbatim; they let the caller pre-seed the intake without
  /// a separate `setAudience()` round-trip.
  Future<Intake> start({
    String? audienceHint,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/start',
        data: <String, dynamic>{
          if (audienceHint != null) 'audience_hint': audienceHint,
          if (metadata != null) 'metadata': metadata,
        },
      );
      return _decodeIntake(response.data, 'POST /v1/intake/start');
    });
  }

  /// `POST /api/v1/intake/handoff/{token}/exchange` — redeem a handoff
  /// token issued by another subproject.
  ///
  /// **This call is unauthenticated** — the [token] is the credential.
  /// The SDK skips Bearer injection for this single request via
  /// [AuthInterceptor.skipAuthExtra]. The receiving subproject's
  /// backend materialises the intake on its side and returns the same
  /// [IntakeHandoff] envelope, this time with the local [Intake]
  /// populated in [IntakeHandoff.intake].
  ///
  /// Idempotency-Key is still attached automatically — the server's
  /// idempotency middleware tolerates the public surface for retry
  /// safety on flaky mobile networks.
  Future<IntakeHandoff> exchange({required String token}) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/handoff/${Uri.encodeComponent(token)}/exchange',
        options: Options(
          extra: <String, dynamic>{AuthInterceptor.skipAuthExtra: true},
        ),
      );
      return _decodeHandoff(
        response.data,
        'POST /v1/intake/handoff/<token>/exchange',
      );
    });
  }

  /// `POST /api/v1/intake/{intake}/voice-record` — attach a recorded
  /// chunk to the intake.
  ///
  /// The patient app uploads the recording to its own CDN (e.g. a
  /// signed S3 URL) and then calls this endpoint with the resulting
  /// [audioUrl] plus the [duration]. The server stores the URL and
  /// length and updates the intake. The [duration] is serialized as
  /// integer seconds (`duration_seconds`), **not** ISO-8601 — matching
  /// the `FollowUpsClient.recordVoice` convention.
  ///
  /// Optional [transcript] is the client-side draft transcript (e.g.
  /// from a local Whisper model); the server may overwrite it with its
  /// own transcription later.
  Future<Intake> voiceRecord(
    String intakeId, {
    required String audioUrl,
    required Duration duration,
    String? transcript,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/voice-record',
        data: <String, dynamic>{
          'audio_url': audioUrl,
          'duration_seconds': duration.inSeconds,
          if (transcript != null) 'transcript': transcript,
        },
      );
      return _decodeIntake(
        response.data,
        'POST /v1/intake/$intakeId/voice-record',
      );
    });
  }

  /// `POST /api/v1/intake/{intake}/voice-finalize` — mark the attached
  /// voice recording as ready for the server-side speech-to-text
  /// pipeline. Idempotent server-side; rate-limited 2/min upstream.
  Future<Intake> voiceFinalize(String intakeId) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/voice-finalize',
      );
      return _decodeIntake(
        response.data,
        'POST /v1/intake/$intakeId/voice-finalize',
      );
    });
  }

  /// `POST /api/v1/intake/{intake}/answers` — replace the structured
  /// answers payload for the intake.
  ///
  /// The full [answers] map is sent — this endpoint replaces rather
  /// than merges, so callers should send the full set of answers each
  /// time. Server returns the updated [Intake] with `status` typically
  /// transitioned from `'open'` to `'in_progress'`.
  Future<Intake> submitAnswers(
    String intakeId, {
    required Map<String, dynamic> answers,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/answers',
        data: <String, dynamic>{'answers': answers},
      );
      return _decodeIntake(
        response.data,
        'POST /v1/intake/$intakeId/answers',
      );
    });
  }

  /// `POST /api/v1/intake/{intake}/audience` — declare the intake's
  /// audience tier.
  ///
  /// [audience] is one of `'patient'`, `'family_member'`, `'caregiver'`
  /// (server-driven — the SDK doesn't enforce the enum). Sets the
  /// downstream routing hint used by `initiateHandoff()`.
  Future<Intake> setAudience(
    String intakeId, {
    required String audience,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/audience',
        data: <String, dynamic>{'audience': audience},
      );
      return _decodeIntake(
        response.data,
        'POST /v1/intake/$intakeId/audience',
      );
    });
  }

  /// `POST /api/v1/intake/{intake}/handoff` — mint a handoff token
  /// scoped to [targetSubprojectDomain].
  ///
  /// The returned [IntakeHandoff] envelope carries the single-use
  /// [IntakeHandoff.token] and the [IntakeHandoff.exchangeUrl] the
  /// receiving subproject (or its mobile BFF) should hit. The
  /// [IntakeHandoff.intake] field is **null** here — the target
  /// subproject hasn't materialised its local intake row yet; that
  /// happens on `exchange()` from the receiving side.
  Future<IntakeHandoff> initiateHandoff(
    String intakeId, {
    required String targetSubprojectDomain,
    Map<String, dynamic>? metadata,
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/handoff',
        data: <String, dynamic>{
          'target_subproject_domain': targetSubprojectDomain,
          if (metadata != null) 'metadata': metadata,
        },
      );
      return _decodeHandoff(
        response.data,
        'POST /v1/intake/$intakeId/handoff',
      );
    });
  }

  /// `GET /api/v1/intake/{intake}/status` — lightweight poll for the
  /// current intake state.
  ///
  /// Returns only the status, last-update timestamp, and a derived
  /// `readyForHandoff` flag — cheaper than refetching the full
  /// [Intake] envelope. Suitable for polling from the patient app's
  /// "waiting for transcription" screen.
  Future<IntakeStatus> status(String intakeId) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/v1/intake/${Uri.encodeComponent(intakeId)}/status',
      );
      final data = (response.data ?? const <String, dynamic>{})['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError(
          'GET /v1/intake/$intakeId/status returned no "data" object.',
        );
      }
      return IntakeStatus.fromJson(data);
    });
  }

  Intake _decodeIntake(Map<String, dynamic>? body, String label) {
    final data = (body ?? const <String, dynamic>{})['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('$label returned no "data" object.');
    }
    return Intake.fromJson(data);
  }

  IntakeHandoff _decodeHandoff(Map<String, dynamic>? body, String label) {
    final data = (body ?? const <String, dynamic>{})['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('$label returned no "data" object.');
    }
    return IntakeHandoff.fromJson(data);
  }
}
