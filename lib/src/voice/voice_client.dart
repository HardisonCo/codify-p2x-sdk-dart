import '../client/p2x_client.dart';
import 'voice_models.dart';

/// Client for the voice-agent bridge (utils/voice-agent).
///
/// Exchanges the caller's Sanctum token (already on [P2xClient]) for
/// short-lived SIP credentials so the app can place a WebRTC call to the
/// voice agent. The SDK deliberately stops at the credentials — the actual
/// SIP signaling + audio (flutter_webrtc / dart_sip_ua) lives in the host
/// app so the SDK stays free of a heavy WebRTC dependency.
class VoiceClient {
  /// Construct against an existing [P2xClient].
  VoiceClient(this._client);

  final P2xClient _client;

  /// POST `/voice/session` — mint a voice session + ephemeral SIP credentials.
  ///
  /// Pass [chainId] to talk to a specific chain the caller owns, or
  /// [programId] to target the caller's running chain for that program.
  /// Omit both to let the server pick the caller's most recent running chain
  /// (else the call starts on the unauthenticated codify path).
  ///
  /// [origin] is one of `app` (default), `web`, or `admin`.
  Future<VoiceSession> createSession({
    int? chainId,
    int? programId,
    String origin = 'app',
  }) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/voice/session',
        data: <String, dynamic>{
          if (chainId != null) 'chain_id': chainId,
          if (programId != null) 'program_id': programId,
          'origin': origin,
        },
      );
      return VoiceSession.fromJson(_data(response.data));
    });
  }

  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty voice session response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    throw StateError(
      'Malformed voice session response — "data" is ${data.runtimeType}',
    );
  }
}
