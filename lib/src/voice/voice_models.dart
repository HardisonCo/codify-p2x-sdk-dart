import 'package:meta/meta.dart';

/// A single WebRTC ICE server (STUN/TURN) the client feeds to its
/// `RTCPeerConnection`. Mirrors `config('voice.ice_servers')` on the API.
@immutable
class IceServer {
  /// Construct.
  const IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  /// Decode one entry of the `ice_servers` array.
  factory IceServer.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    return IceServer(
      urls: rawUrls is List
          ? rawUrls.map((dynamic u) => u.toString()).toList(growable: false)
          : <String>[rawUrls.toString()],
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  /// One or more `stun:`/`turn:` URLs.
  final List<String> urls;

  /// TURN username (absent for STUN-only servers).
  final String? username;

  /// TURN credential (absent for STUN-only servers).
  final String? credential;

  /// Shape accepted by `flutter_webrtc`'s `RTCPeerConnection` config.
  Map<String, dynamic> toPeerConnectionMap() => <String, dynamic>{
        'urls': urls,
        if (username != null) 'username': username,
        if (credential != null) 'credential': credential,
      };
}

/// The ephemeral SIP credentials + endpoint the client REGISTERs against
/// Asterisk's WebRTC (WSS) transport to place the call.
@immutable
class SipCredentials {
  /// Construct.
  const SipCredentials({
    required this.username,
    required this.secret,
    required this.realm,
    required this.wss,
    required this.agentExtension,
    required this.uri,
  });

  /// Decode the `sip` block.
  factory SipCredentials.fromJson(Map<String, dynamic> json) {
    return SipCredentials(
      username: (json['username'] ?? '') as String,
      secret: (json['secret'] ?? '') as String,
      realm: (json['realm'] ?? '') as String,
      wss: (json['wss'] ?? '') as String,
      agentExtension: (json['agent_extension'] ?? '') as String,
      uri: (json['uri'] ?? '') as String,
    );
  }

  /// Ephemeral SIP auth username (e.g. `vs_xxxxx`).
  final String username;

  /// Ephemeral SIP secret. Short-lived; never a Sanctum token.
  final String secret;

  /// SIP realm/domain the endpoint registers under (e.g. `sip.ycaaa.ai`).
  final String realm;

  /// WSS signaling URL for SIP-over-WebSocket.
  final String wss;

  /// The dialplan extension that routes into the agent Stasis app.
  final String agentExtension;

  /// The request URI to dial (`sip:agent@realm`).
  final String uri;
}

/// The result of `POST /api/voice/session` — everything a WebRTC client needs
/// to call the voice agent, bound to a [chainId] so voice and web share the
/// same agt conversation memory.
@immutable
class VoiceSession {
  /// Construct.
  const VoiceSession({
    required this.sessionId,
    required this.sip,
    this.chainId,
    this.expiresIn,
    this.iceServers = const <IceServer>[],
  });

  /// Decode from the inner `data` block of the Laravel envelope.
  factory VoiceSession.fromJson(Map<String, dynamic> json) {
    final ice = json['ice_servers'];
    return VoiceSession(
      sessionId: (json['session_id'] ?? '') as String,
      chainId: json['chain_id'] == null
          ? null
          : (json['chain_id'] as num).toInt(),
      expiresIn: json['expires_in'] == null
          ? null
          : (json['expires_in'] as num).toInt(),
      sip: SipCredentials.fromJson(
        (json['sip'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      iceServers: ice is List
          ? ice
              .whereType<Map<String, dynamic>>()
              .map(IceServer.fromJson)
              .toList(growable: false)
          : const <IceServer>[],
    );
  }

  /// Opaque handle the client carries into the SIP call so Asterisk can
  /// resolve it back to {user, chain, subproject}.
  final String sessionId;

  /// The ProtocolPersonalChain this voice call talks to. Null when the caller
  /// has no running chain yet — the agent then uses the unauth codify path.
  final int? chainId;

  /// Seconds until the session/credentials expire.
  final int? expiresIn;

  /// Ephemeral SIP credentials + endpoint.
  final SipCredentials sip;

  /// STUN/TURN servers for the WebRTC peer connection.
  final List<IceServer> iceServers;
}
