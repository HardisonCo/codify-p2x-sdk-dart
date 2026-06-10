/// Canonical names of the Pusher / Echo channels broadcast by the P2X API
/// (`P2X/api/routes/channels.php`). Centralising them here keeps consumer
/// apps from drifting on the spelling.
abstract final class ChannelNames {
  /// Private channel scoped to an authenticated user — receives nudges,
  /// notifications, job-progress events. Requires broadcast auth via
  /// [ChatClient.authBroadcast] (the API uses the same `/broadcasting/auth`
  /// endpoint for Pusher and Echo).
  static String user(int id) => 'private-user-$id';

  /// Channel for an anonymous guest (MOB-style). [sessionKey] is the SDK's
  /// guest session id.
  static String guest(String sessionKey) => 'private-guest-$sessionKey';

  /// All agents owned by a subproject. Useful for ops dashboards.
  static String subprojectAgents(int subprojectId) =>
      'private-subproject-$subprojectId-agents';

  /// Codify ontology refresh signal — broadcast when a code/term/condition
  /// in the shared ontology is updated.
  static const String codifyOntology = 'private-codify-ontology';

  /// Per-session pipeline state — the codify-pipeline workflow publishes
  /// progress events here for the UI to render.
  static String pipelineState(String session) => 'private-pipeline-state-$session';
}
