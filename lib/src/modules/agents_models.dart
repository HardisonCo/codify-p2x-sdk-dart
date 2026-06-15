import 'package:meta/meta.dart';

/// The result of `POST /api/wizard/resource-owner` — a freshly-persisted
/// **draft** resource listing (`ResourceListing`, status `draft`).
///
/// Decoded from the `{data: {resource_listing_id, status, subproject_id}}`
/// envelope returned by `ResourceOwnerWizardController::store`.
@immutable
class ResourceListingDraft {
  /// Construct.
  const ResourceListingDraft({
    required this.resourceListingId,
    required this.status,
    required this.subprojectId,
  });

  /// Decode from the unwrapped `data` body.
  factory ResourceListingDraft.fromJson(Map<String, dynamic> json) =>
      ResourceListingDraft(
        resourceListingId: _intOf(json['resource_listing_id']) ?? 0,
        status: (json['status'] ?? '') as String,
        subprojectId: _intOf(json['subproject_id']) ?? 0,
      );

  /// The created listing's primary key.
  final int resourceListingId;

  /// Listing status — `draft` on create.
  final String status;

  /// The tenant subproject the listing belongs to.
  final int subprojectId;
}

/// The result of `POST /api/wizard/resource-owner/{listing}/activate` — the
/// L3 resource agent spawned and the listing flipped `draft → active`.
///
/// Decoded from `{data: {resource_listing_id, agent_id, listing_status,
/// activated_at}}`.
@immutable
class ResourceListingActivation {
  /// Construct.
  const ResourceListingActivation({
    required this.resourceListingId,
    required this.agentId,
    required this.listingStatus,
    this.activatedAt,
  });

  /// Decode from the unwrapped `data` body.
  factory ResourceListingActivation.fromJson(Map<String, dynamic> json) =>
      ResourceListingActivation(
        resourceListingId: _intOf(json['resource_listing_id']) ?? 0,
        agentId: _intOf(json['agent_id']) ?? 0,
        listingStatus: (json['listing_status'] ?? '') as String,
        activatedAt: _dateOf(json['activated_at']),
      );

  /// The activated listing's primary key.
  final int resourceListingId;

  /// The spawned L3 resource agent's primary key.
  final int agentId;

  /// Listing status — `active` after a successful activation.
  final String listingStatus;

  /// When the listing was activated.
  final DateTime? activatedAt;
}

/// The result of `POST /api/wizard/resource-owner/{listing}/claim` — a worker
/// claiming a market gig slot (Staffing v2).
///
/// The controller returns one of three shapes depending on the auto-rules
/// outcome, all decoded here:
///   * **fill** (200): `{resource_listing_id, listing_status, wizard_invite_id,
///     role_id, protocol_id}`.
///   * **escalate** (202): `{resource_listing_id, listing_status, decision}`
///     — [decision] is `escalate`; the invite ids are `null`.
@immutable
class ResourceListingClaim {
  /// Construct.
  const ResourceListingClaim({
    required this.resourceListingId,
    required this.listingStatus,
    this.wizardInviteId,
    this.roleId,
    this.protocolId,
    this.decision,
  });

  /// Decode from the unwrapped `data` body.
  factory ResourceListingClaim.fromJson(Map<String, dynamic> json) =>
      ResourceListingClaim(
        resourceListingId: _intOf(json['resource_listing_id']) ?? 0,
        listingStatus: (json['listing_status'] ?? '') as String,
        wizardInviteId: _intOf(json['wizard_invite_id']),
        roleId: _intOf(json['role_id']),
        protocolId: _intOf(json['protocol_id']),
        decision: json['decision'] as String?,
      );

  /// The claimed listing's primary key.
  final int resourceListingId;

  /// Listing status after the claim.
  final String listingStatus;

  /// The minted wizard-invite id (`null` on an escalate outcome).
  final int? wizardInviteId;

  /// The role the invite grants (`null` on escalate).
  final int? roleId;

  /// The protocol the invite is bound to (`null` on escalate).
  final int? protocolId;

  /// The auto-rules decision — only present on the `escalate` (202) outcome.
  final String? decision;

  /// Whether the claim was escalated for manual review rather than filled.
  bool get isEscalated => decision == 'escalate';
}

int? _intOf(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _dateOf(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
