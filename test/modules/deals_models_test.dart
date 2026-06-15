// JSON-decode tests for the Deal Wizard models (Modules/Deals).

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/modules/deals_models.dart';

void main() {
  group('Deal.fromJson', () {
    test('decodes the flat DealResource shape with a UUID id', () {
      const guid = 'abcd1234-0000-0000-0000-000000000001';
      final d = Deal.fromJson(<String, dynamic>{
        'deal_id': guid,
        'id': guid,
        'user_id': 42,
        'subproject_id': 3,
        'tld': 'codify.healthcare',
        'state': 'codified',
        'wizard_step': 2,
        'current_step_idx': 0,
        'problem': <String, dynamic>{'statement': 'x', 'title': 'T'},
        'solutions': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'sol-1'},
        ],
        'selected_solution_idx': 1,
        'stakeholders': <Map<String, dynamic>>[
          <String, dynamic>{'role': 'gastroenterologist'},
        ],
        'financing': <String, dynamic>{'total_cents': 37700},
        'expertise': <String, dynamic>{'codesets': <String>['ICD-10']},
        'pipeline_steps': <dynamic>[],
        'outcome_score': 75,
        'outcome_report': <String, dynamic>{'criteria_met': 2},
        'ontology_class': 'codify.healthcare/X',
        'ontology_version': 'v3',
        'applicant_type': 'Builder',
        'budget_tier': 'lt30k',
        'path_tier': 'blue',
        'created_at': '2026-06-01T08:00:00+00:00',
        'updated_at': '2026-06-02T08:00:00+00:00',
        'completed_at': null,
      });

      expect(d.id, guid);
      expect(d.state, 'codified');
      expect(d.userId, 42);
      expect(d.subprojectId, 3);
      expect(d.tld, 'codify.healthcare');
      expect(d.wizardStep, 2);
      expect(d.currentStepIdx, 0);
      expect(d.problem['title'], 'T');
      expect(d.solutions, hasLength(1));
      expect(d.selectedSolutionIdx, 1);
      expect(d.stakeholders.first, isA<Map<dynamic, dynamic>>());
      expect(d.financing['total_cents'], 37700);
      expect(d.expertise['codesets'], <String>['ICD-10']);
      expect(d.outcomeScore, 75);
      expect(d.outcomeReport?['criteria_met'], 2);
      expect(d.ontologyVersion, 'v3');
      expect(d.applicantType, 'Builder');
      expect(d.budgetTier, 'lt30k');
      expect(d.pathTier, 'blue');
      expect(d.createdAt, isNotNull);
      expect(d.completedAt, isNull);
    });

    test('prefers deal_id but falls back to id', () {
      final d = Deal.fromJson(<String, dynamic>{
        'id': 'only-id-uuid',
        'state': 'analyzing',
      });
      expect(d.id, 'only-id-uuid');
    });

    test('stashes unknown top-level fields in extras', () {
      final d = Deal.fromJson(<String, dynamic>{
        'deal_id': 'g',
        'state': 'analyzing',
        'something_new': <String, dynamic>{'a': 1},
      });
      expect(d.extras['something_new'], <String, dynamic>{'a': 1});
    });

    test('tolerates missing optional fields', () {
      final d = Deal.fromJson(<String, dynamic>{
        'deal_id': 'g',
        'state': 'analyzing',
      });
      expect(d.problem, isEmpty);
      expect(d.solutions, isEmpty);
      expect(d.userId, isNull);
      expect(d.outcomeScore, isNull);
    });
  });

  group('DealFile.fromJson', () {
    test('decodes a deal_files row', () {
      final f = DealFile.fromJson(<String, dynamic>{
        'id': 12,
        'deal_id': 'g-uuid',
        'file_path': 'deal-files/g-uuid/x.png',
        'file_type': 'logo',
        'mime_type': 'image/png',
        'uploaded_by_user_id': 9,
      });
      expect(f.id, 12);
      expect(f.dealId, 'g-uuid');
      expect(f.filePath, 'deal-files/g-uuid/x.png');
      expect(f.fileType, 'logo');
      expect(f.mimeType, 'image/png');
      expect(f.uploadedByUserId, 9);
    });
  });

  group('DealEventsPage.fromJson', () {
    test('decodes events + pagination', () {
      final p = DealEventsPage.fromJson(<String, dynamic>{
        'events': <Map<String, dynamic>>[
          <String, dynamic>{'sequence': 1, 'event_type': 'deal.created'},
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'per_page': 50,
          'current_page': 1,
          'last_page': 1,
        },
      });
      expect(p.events, hasLength(1));
      expect(p.events.first['event_type'], 'deal.created');
      expect(p.total, 1);
      expect(p.perPage, 50);
    });

    test('defaults pagination when missing', () {
      final p = DealEventsPage.fromJson(<String, dynamic>{
        'events': <Map<String, dynamic>>[],
      });
      expect(p.events, isEmpty);
      expect(p.currentPage, 1);
      expect(p.lastPage, 1);
    });
  });

  group('DealVerificationResult.fromJson', () {
    test('decodes the bespoke verify body', () {
      final r = DealVerificationResult.fromJson(<String, dynamic>{
        'deal_id': 'g',
        'state': 'completed',
        'outcome_score': 92,
        'outcome_class': 'success',
        'outcome_report': <String, dynamic>{'a': 1},
      });
      expect(r.dealId, 'g');
      expect(r.state, 'completed');
      expect(r.outcomeScore, 92);
      expect(r.outcomeClass, 'success');
      expect(r.outcomeReport['a'], 1);
    });
  });

  group('ComputeDeposit.fromJson', () {
    test('decodes client_secret', () {
      final dep = ComputeDeposit.fromJson(<String, dynamic>{
        'client_secret': 'pi_x_secret_y',
      });
      expect(dep.clientSecret, 'pi_x_secret_y');
    });
  });
}
