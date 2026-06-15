// JSON-decode tests for the Agents resource-owner wizard models
// (Modules/Agents — ResourceOwnerWizardController response shapes).

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/modules/agents_models.dart';

void main() {
  group('ResourceListingDraft.fromJson', () {
    test('decodes the store response', () {
      final d = ResourceListingDraft.fromJson(<String, dynamic>{
        'resource_listing_id': 55,
        'status': 'draft',
        'subproject_id': 7,
      });
      expect(d.resourceListingId, 55);
      expect(d.status, 'draft');
      expect(d.subprojectId, 7);
    });

    test('coerces string-numeric ids and tolerates missing status', () {
      final d = ResourceListingDraft.fromJson(<String, dynamic>{
        'resource_listing_id': '55',
        'subproject_id': '7',
      });
      expect(d.resourceListingId, 55);
      expect(d.subprojectId, 7);
      expect(d.status, '');
    });
  });

  group('ResourceListingActivation.fromJson', () {
    test('decodes the activate response', () {
      final a = ResourceListingActivation.fromJson(<String, dynamic>{
        'resource_listing_id': 55,
        'agent_id': 900,
        'listing_status': 'active',
        'activated_at': '2026-06-15T09:00:00+00:00',
      });
      expect(a.resourceListingId, 55);
      expect(a.agentId, 900);
      expect(a.listingStatus, 'active');
      expect(a.activatedAt, DateTime.parse('2026-06-15T09:00:00+00:00'));
    });

    test('tolerates a null activated_at', () {
      final a = ResourceListingActivation.fromJson(<String, dynamic>{
        'resource_listing_id': 55,
        'agent_id': 900,
        'listing_status': 'active',
        'activated_at': null,
      });
      expect(a.activatedAt, isNull);
    });
  });

  group('ResourceListingClaim.fromJson', () {
    test('decodes a fill outcome', () {
      final c = ResourceListingClaim.fromJson(<String, dynamic>{
        'resource_listing_id': 77,
        'listing_status': 'active',
        'wizard_invite_id': 1234,
        'role_id': 5,
        'protocol_id': 9,
      });
      expect(c.resourceListingId, 77);
      expect(c.wizardInviteId, 1234);
      expect(c.roleId, 5);
      expect(c.protocolId, 9);
      expect(c.decision, isNull);
      expect(c.isEscalated, isFalse);
    });

    test('decodes an escalate outcome with null invite ids', () {
      final c = ResourceListingClaim.fromJson(<String, dynamic>{
        'resource_listing_id': 77,
        'listing_status': 'active',
        'decision': 'escalate',
      });
      expect(c.decision, 'escalate');
      expect(c.isEscalated, isTrue);
      expect(c.wizardInviteId, isNull);
      expect(c.roleId, isNull);
      expect(c.protocolId, isNull);
    });
  });
}
