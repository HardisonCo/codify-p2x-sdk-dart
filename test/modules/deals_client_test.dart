// Contract tests for DealsClient + DealStepClient — the YCaaS Deal Wizard
// surface (`Modules/Deals`, /api/wizard/deal/* + /api/deals/{id}/steps/*).
//
// Routes covered (17 wizard/deal + 3 step-claim):
//   POST   /wizard/deal/define
//   GET    /wizard/deal/{id}/status
//   GET    /wizard/deal/{id}/events
//   POST   /wizard/deal/{id}/required-info
//   POST   /wizard/deal/{id}/codify
//   POST   /wizard/deal/{id}/select-solution
//   POST   /wizard/deal/{id}/setup
//   POST   /wizard/deal/{id}/start
//   PATCH  /wizard/deal/{id}/metadata        (→ POST ?_method=PATCH)
//   PATCH  /wizard/deal/{id}/details         (→ POST ?_method=PATCH)
//   POST   /wizard/deal/{id}/files           (multipart)
//   DELETE /wizard/deal/{id}/files/{file_id}
//   PATCH  /wizard/deal/{id}/path            (→ POST ?_method=PATCH)
//   POST   /wizard/deal/{id}/submit
//   POST   /wizard/deal/{id}/compute-deposit
//   POST   /wizard/deal/{id}/verify/{execution_id}
//   POST   /deals/{id}/steps/{idx}/claim
//   POST   /deals/{id}/steps/{idx}/submit
//   POST   /deals/{id}/steps/{idx}/release
//
// Asserts: method, path (incl. _method query for PATCH), request body,
// the auth / X-Domain / Idempotency-Key headers, response decoding, and
// negative paths (422 → ValidationException, 401 → UnauthorizedException +
// onUnauthorized callback).

import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/deal_step_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/deals_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

const _guid = '11111111-2222-3333-4444-555555555555';

/// A flat (non-enveloped) deal body matching `DealResource::toArray()`
/// merged with `{deal_id, state}` — the actual `/wizard/deal/*` shape.
Map<String, dynamic> dealBody({
  String id = _guid,
  String state = 'analyzing',
}) =>
    <String, dynamic>{
      'deal_id': id,
      'id': id,
      'user_id': 42,
      'subproject_id': 3,
      'tld': 'codify.healthcare',
      'state': state,
      'wizard_step': 1,
      'current_step_idx': null,
      'problem': <String, dynamic>{'statement': 'Medication review'},
      'solutions': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'sol-1', 'description': 'A'},
        <String, dynamic>{'id': 'sol-2', 'description': 'B'},
        <String, dynamic>{'id': 'sol-3', 'description': 'C'},
      ],
      'selected_solution_idx': null,
      'stakeholders': <Map<String, dynamic>>[],
      'financing': <String, dynamic>{'total_cents': 37700},
      'expertise': <String, dynamic>{},
      'pipeline_steps': <dynamic>[],
      'outcome_score': null,
      'outcome_report': null,
      'ontology_class': 'codify.healthcare/MedicationReview',
      'ontology_version': 'v3',
      'created_at': '2026-06-01T08:00:00+00:00',
      'updated_at': '2026-06-01T08:00:00+00:00',
      'completed_at': null,
    };

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late DealsClient deals;
  late DealStepClient steps;
  var unauthorizedFired = 0;

  setUp(() {
    unauthorizedFired = 0;
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
        onUnauthorized: () => unauthorizedFired++,
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    deals = DealsClient(base);
    steps = DealStepClient(base);
  });

  group('DealsClient.define', () {
    test('POSTs /wizard/deal/define with statement only (no subproject_id)',
        () async {
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{'statement': 'Medication review'},
      );

      final d = await deals.define(statement: 'Medication review');

      expect(d, isA<Deal>());
      expect(d.id, _guid);
      expect(d.state, 'analyzing');
      expect(d.solutions, hasLength(3));
      expect(d.financing['total_cents'], 37700);
    });

    test('includes tld when supplied', () async {
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{
          'statement': 'Need a YC for health in Boston',
          'tld': 'healthcare',
        },
      );

      final d = await deals.define(
        statement: 'Need a YC for health in Boston',
        tld: 'healthcare',
      );
      expect(d.id, _guid);
    });

    test('attaches Authorization, X-Domain and Idempotency-Key headers',
        () async {
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(200, dealBody()),
        data: Matchers.any,
      );

      // The interceptor stack runs regardless of which method issues the
      // request — exercise it directly so we can read requestOptions back.
      final resp = await base.dio.post<Map<String, dynamic>>(
        '/wizard/deal/define',
        data: <String, dynamic>{'statement': 'x'},
      );

      final headers = resp.requestOptions.headers;
      expect(headers['Authorization'], 'Bearer tok-abc');
      expect(headers['X-Domain'], 'nutriscan.codify.ai');
      expect(headers['Idempotency-Key'], isA<String>());
      expect((headers['Idempotency-Key'] as String).isNotEmpty, isTrue);
    });

    test('422 surfaces as ValidationException with field errors', () async {
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The statement field is required.',
          'errors': <String, dynamic>{
            'statement': <String>['The statement field is required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => deals.define(statement: ''),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['statement'],
            'statement errors',
            <String>['The statement field is required.'],
          ),
        ),
      );
    });

    test('401 throws UnauthorizedException and fires onUnauthorized',
        () async {
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(401, <String, dynamic>{'message': 'Unauthenticated.'}),
        data: Matchers.any,
      );

      await expectLater(
        deals.define(statement: 'x'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(unauthorizedFired, 1);
    });
  });

  group('DealsClient.status + events', () {
    test('GETs /wizard/deal/{id}/status', () async {
      adapter.onGet(
        '/wizard/deal/$_guid/status',
        (req) => req.reply(200, dealBody(state: 'setup')),
      );

      final d = await deals.status(dealId: _guid);
      expect(d.id, _guid);
      expect(d.state, 'setup');
      expect(d.tld, 'codify.healthcare');
    });

    test('GETs /wizard/deal/{id}/events and decodes pagination', () async {
      adapter.onGet(
        '/wizard/deal/$_guid/events',
        (req) => req.reply(200, <String, dynamic>{
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'sequence': 1,
              'event_type': 'deal.created',
            },
            <String, dynamic>{
              'sequence': 2,
              'event_type': 'deal.info_collected',
            },
          ],
          'pagination': <String, dynamic>{
            'total': 2,
            'per_page': 50,
            'current_page': 1,
            'last_page': 1,
          },
        }),
      );

      final page = await deals.events(dealId: _guid);
      expect(page.events, hasLength(2));
      expect(page.events.first['event_type'], 'deal.created');
      expect(page.total, 2);
      expect(page.perPage, 50);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
    });

    test('passes per_page query param', () async {
      adapter.onGet(
        '/wizard/deal/$_guid/events',
        (req) => req.reply(200, <String, dynamic>{
          'events': <Map<String, dynamic>>[],
          'pagination': <String, dynamic>{
            'total': 0,
            'per_page': 10,
            'current_page': 1,
            'last_page': 1,
          },
        }),
        queryParameters: <String, dynamic>{'per_page': 10},
      );

      final page = await deals.events(dealId: _guid, perPage: 10);
      expect(page.perPage, 10);
    });
  });

  group('DealsClient.requiredInfo', () {
    test('POSTs answers wrapped in {answers}', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/required-info',
        (req) => req.reply(200, dealBody(state: 'codified')),
        data: <String, dynamic>{
          'answers': <String, dynamic>{'medication': 'Skyrizi', 'dose': '150mg'},
        },
      );

      final d = await deals.requiredInfo(
        dealId: _guid,
        answers: <String, dynamic>{'medication': 'Skyrizi', 'dose': '150mg'},
      );
      expect(d.state, 'codified');
    });

    test('422 missing_required_info surfaces (validation-ish 422)', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/required-info',
        (req) => req.reply(422, <String, dynamic>{
          'error': 'missing_required_info',
          'missing': <String>['dose'],
        }),
        data: Matchers.any,
      );

      await expectLater(
        deals.requiredInfo(dealId: _guid, answers: <String, dynamic>{}),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('DealsClient.codify + selectSolution', () {
    test('POSTs /codify with empty body', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/codify',
        (req) => req.reply(200, dealBody(state: 'codified')),
        data: null,
      );

      final d = await deals.codify(dealId: _guid);
      expect(d.state, 'codified');
    });

    test('POSTs /select-solution with solution_idx', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/select-solution',
        (req) => req.reply(200, dealBody(state: 'codified')),
        data: <String, dynamic>{'solution_idx': 1},
      );

      final d = await deals.selectSolution(dealId: _guid, solutionIdx: 1);
      expect(d.id, _guid);
    });
  });

  group('DealsClient.setup + start', () {
    test('POSTs /setup (empty body) → setup', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/setup',
        (req) => req.reply(200, dealBody(state: 'setup')),
        data: null,
      );
      final d = await deals.setup(dealId: _guid);
      expect(d.state, 'setup');
    });

    test('POSTs /start (empty body) → executing', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/start',
        (req) => req.reply(200, dealBody(state: 'executing')),
        data: null,
      );
      final d = await deals.start(dealId: _guid);
      expect(d.state, 'executing');
    });

    test('start 422 invalid_state surfaces', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/start',
        (req) => req.reply(422, <String, dynamic>{
          'error': 'invalid_state',
          'message': 'Deal must be in state=setup to start (got analyzing)',
        }),
        data: null,
      );
      await expectLater(
        deals.start(dealId: _guid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('DealsClient.patchMetadata (PATCH → POST ?_method=PATCH)', () {
    test('rewrites to POST with _method=PATCH and sends the body', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/metadata',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{
          'title': 'Crohn efficacy program',
          'description': 'A' * 60,
          'applicant_type': 'Builder',
          'related_industries': <String>['healthcare'],
        },
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );

      final d = await deals.patchMetadata(
        dealId: _guid,
        title: 'Crohn efficacy program',
        description: 'A' * 60,
        applicantType: 'Builder',
        relatedIndustries: <String>['healthcare'],
      );
      expect(d.id, _guid);
    });

    test('422 surfaces for an out-of-enum applicant_type', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/metadata',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The selected applicant type is invalid.',
          'errors': <String, dynamic>{
            'applicant_type': <String>['The selected applicant type is invalid.'],
          },
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );

      await expectLater(
        deals.patchMetadata(
          dealId: _guid,
          title: 't',
          description: 'A' * 60,
          applicantType: 'Nope',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('DealsClient.patchDetails (PATCH → POST ?_method=PATCH)', () {
    test('sends budget_tier + optional fields', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/details',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{
          'budget_tier': 'lt30k',
          'customer_user_id': 7,
          'start_date': '2026-07-01',
          'end_date': '2026-09-01',
        },
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );

      final d = await deals.patchDetails(
        dealId: _guid,
        budgetTier: 'lt30k',
        customerUserId: 7,
        startDate: '2026-07-01',
        endDate: '2026-09-01',
      );
      expect(d.id, _guid);
    });

    test('budget_tier only (no optional fields)', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/details',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{'budget_tier': 'gte100k'},
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );

      final d = await deals.patchDetails(dealId: _guid, budgetTier: 'gte100k');
      expect(d.id, _guid);
    });
  });

  group('DealsClient.uploadFile / deleteFile', () {
    test('POSTs multipart to /files and decodes the DealFile (201)', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/files',
        (req) => req.reply(201, <String, dynamic>{
          'id': 88,
          'deal_id': _guid,
          'file_path': 'deal-files/$_guid/abc.pdf',
          'file_type': 'document',
          'mime_type': 'application/pdf',
          'uploaded_by_user_id': 42,
          'created_at': '2026-06-01T08:00:00+00:00',
          'updated_at': '2026-06-01T08:00:00+00:00',
        }),
        data: Matchers.any,
      );

      final f = await deals.uploadFile(
        dealId: _guid,
        fileType: 'document',
        bytes: <int>[1, 2, 3, 4],
        filename: 'abc.pdf',
      );

      expect(f, isA<DealFile>());
      expect(f.id, 88);
      expect(f.dealId, _guid);
      expect(f.fileType, 'document');
      expect(f.mimeType, 'application/pdf');
      expect(f.uploadedByUserId, 42);
    });

    test('DELETEs /files/{file_id} and returns on 204', () async {
      adapter.onDelete(
        '/wizard/deal/$_guid/files/88',
        (req) => req.reply(204, null),
      );

      await expectLater(
        deals.deleteFile(dealId: _guid, fileId: 88),
        completes,
      );
    });
  });

  group('DealsClient.patchPath (PATCH → POST ?_method=PATCH)', () {
    test('sends path_tier', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/path',
        (req) => req.reply(200, dealBody()),
        data: <String, dynamic>{'path_tier': 'blue'},
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );

      final d = await deals.patchPath(dealId: _guid, pathTier: 'blue');
      expect(d.id, _guid);
    });
  });

  group('DealsClient.submit', () {
    test('POSTs /submit (empty body) → awaiting_compute', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/submit',
        (req) => req.reply(200, dealBody(state: 'awaiting_compute')),
        data: null,
      );

      final d = await deals.submit(dealId: _guid);
      expect(d.state, 'awaiting_compute');
    });

    test('422 missing_wizard_data surfaces', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/submit',
        (req) => req.reply(422, <String, dynamic>{
          'error': 'missing_wizard_data',
          'missing': <String>['path_tier'],
        }),
        data: null,
      );

      await expectLater(
        deals.submit(dealId: _guid),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('DealsClient.computeDeposit', () {
    test('POSTs amount_cents and decodes client_secret', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/compute-deposit',
        (req) => req.reply(200, <String, dynamic>{
          'client_secret': 'pi_123_secret_abc',
        }),
        data: <String, dynamic>{'amount_cents': 10000},
      );

      final dep = await deals.computeDeposit(dealId: _guid, amountCents: 10000);
      expect(dep, isA<ComputeDeposit>());
      expect(dep.clientSecret, 'pi_123_secret_abc');
    });

    test('422 for an invalid tier amount', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/compute-deposit',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The selected amount cents is invalid.',
          'errors': <String, dynamic>{
            'amount_cents': <String>['The selected amount cents is invalid.'],
          },
        }),
        data: Matchers.any,
      );

      await expectLater(
        deals.computeDeposit(dealId: _guid, amountCents: 777),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('DealsClient.verify', () {
    test('POSTs /verify/{execution_id} and decodes the bespoke result',
        () async {
      adapter.onPost(
        '/wizard/deal/$_guid/verify/9',
        (req) => req.reply(200, <String, dynamic>{
          'deal_id': _guid,
          'state': 'completed',
          'outcome_score': 75,
          'outcome_class': 'partial_success',
          'outcome_report': <String, dynamic>{'criteria_met': 2},
        }),
        data: null,
      );

      final r = await deals.verify(dealId: _guid, executionId: 9);
      expect(r, isA<DealVerificationResult>());
      expect(r.dealId, _guid);
      expect(r.state, 'completed');
      expect(r.outcomeScore, 75);
      expect(r.outcomeClass, 'partial_success');
      expect(r.outcomeReport['criteria_met'], 2);
    });

    test('409 illegal_state surfaces as a 409 ApiException', () async {
      adapter.onPost(
        '/wizard/deal/$_guid/verify/9',
        (req) => req.reply(409, <String, dynamic>{
          'error': 'illegal_state',
          'message': 'illegal state transition',
        }),
        data: null,
      );

      await expectLater(
        deals.verify(dealId: _guid, executionId: 9),
        throwsA(
          isA<ApiException>().having((e) => e.status, 'status', 409),
        ),
      );
    });
  });

  group('DealStepClient', () {
    test('claim POSTs {actor_ref} and decodes the claim envelope', () async {
      adapter.onPost(
        '/deals/$_guid/steps/0/claim',
        (req) => req.reply(200, <String, dynamic>{
          'claim_token': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'expires_at': '2026-06-01T09:00:00+00:00',
        }),
        data: <String, dynamic>{'actor_ref': 'agent:codify-agent-default'},
      );

      final r = await steps.claim(
        dealId: _guid,
        stepIdx: 0,
        actorRef: 'agent:codify-agent-default',
      );
      expect(r['claim_token'], 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
      expect(r['expires_at'], '2026-06-01T09:00:00+00:00');
    });

    test('409 already_claimed surfaces', () async {
      adapter.onPost(
        '/deals/$_guid/steps/0/claim',
        (req) => req.reply(409, <String, dynamic>{
          'error': 'already_claimed',
          'claim_token': null,
        }),
        data: Matchers.any,
      );

      await expectLater(
        steps.claim(dealId: _guid, stepIdx: 0, actorRef: 'x'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
    });

    test('submit POSTs {claim_token, result} and decodes {ok}', () async {
      adapter.onPost(
        '/deals/$_guid/steps/0/submit',
        (req) => req.reply(200, <String, dynamic>{
          'ok': true,
          'contract_validated': true,
        }),
        data: <String, dynamic>{
          'claim_token': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'result': <String, dynamic>{'contract_validated': true},
        },
      );

      final r = await steps.submit(
        dealId: _guid,
        stepIdx: 0,
        claimToken: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        result: <String, dynamic>{'contract_validated': true},
      );
      expect(r['ok'], isTrue);
      expect(r['contract_validated'], isTrue);
    });

    test('release POSTs {claim_token, reason} and decodes {ok}', () async {
      adapter.onPost(
        '/deals/$_guid/steps/0/release',
        (req) => req.reply(200, <String, dynamic>{'ok': true}),
        data: <String, dynamic>{
          'claim_token': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          'reason': 'timed out',
        },
      );

      final r = await steps.release(
        dealId: _guid,
        stepIdx: 0,
        claimToken: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        reason: 'timed out',
      );
      expect(r['ok'], isTrue);
    });
  });
}
