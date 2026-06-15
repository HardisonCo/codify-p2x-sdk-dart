import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/agents_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient({
  String? token,
  String? domain,
  void Function()? onUnauthorized,
}) =>
    P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: token == null ? null : () => token,
        getDomain: domain == null ? null : () => domain,
        onUnauthorized: onUnauthorized,
      ),
    );

void main() {
  group('AgentsClient.list', () {
    test('GETs /agents and returns a list', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/agents',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'a-1', 'name': 'Agent A'},
            <String, dynamic>{'id': 'a-2', 'name': 'Agent B'},
          ],
        }),
      );
      final agents = AgentsClient(p2x);
      final list = await agents.list();
      expect(list, hasLength(2));
    });
  });

  group('AgentsClient.create', () {
    test('POSTs /agents with name + type', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'id': 'a-new',
            'name': 'Triage Bot',
            'type': 'specialist',
          },
        }),
        data: <String, dynamic>{
          'name': 'Triage Bot',
          'type': 'specialist',
        },
      );
      final agents = AgentsClient(p2x);
      final r = await agents.create(name: 'Triage Bot', type: 'specialist');
      expect(r['id'], 'a-new');
    });
  });

  group('AgentsClient.executeProtocol', () {
    test('POSTs /agents/execute-protocol with protocol_id', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/execute-protocol',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'success': true,
            'execution_id': 99,
            'status': 'running',
            'needs_input': false,
          },
        }),
        data: <String, dynamic>{'protocol_id': 7},
      );
      final agents = AgentsClient(p2x);
      final r = await agents.executeProtocol(protocolId: 7);
      expect(r['execution_id'], 99);
      expect(r['status'], 'running');
    });
  });

  group('AgentsClient.activate / deactivate / clone', () {
    test('lifecycle endpoints hit the right routes', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter
        ..onPost(
          '/agents/a-1/activate',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': <String, dynamic>{'id': 'a-1', 'status': 'active'},
          }),
          data: null,
        )
        ..onPost(
          '/agents/a-1/deactivate',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': <String, dynamic>{'id': 'a-1', 'status': 'inactive'},
          }),
          data: null,
        )
        ..onPost(
          '/agents/a-1/clone',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': <String, dynamic>{'id': 'a-2', 'name': 'Triage Clone'},
          }),
          data: <String, dynamic>{'name': 'Triage Clone'},
        );

      final agents = AgentsClient(p2x);
      expect((await agents.activate(uuid: 'a-1'))['status'], 'active');
      expect((await agents.deactivate(uuid: 'a-1'))['status'], 'inactive');
      final cloned = await agents.clone(uuid: 'a-1', name: 'Triage Clone');
      expect(cloned['id'], 'a-2');
    });
  });

  group('AgentsClient.addTool', () {
    test('POSTs /agents/{uuid}/tools/{tool}', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/a-1/tools/calculator',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'id': 'a-1',
            'tools': <String>['calculator'],
          },
        }),
        data: null,
      );
      final agents = AgentsClient(p2x);
      final r = await agents.addTool(uuid: 'a-1', tool: 'calculator');
      expect(r['tools'], contains('calculator'));
    });
  });

  group('AgentsClient.processIntent (public)', () {
    test('POSTs /agents/intelligent/intent/process and returns flat envelope',
        () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/intelligent/intent/process',
        (req) => req.reply(200, <String, dynamic>{
          'status': 'success',
          'data': <String, dynamic>{
            'classification': <String, dynamic>{'top': 'medication-question'},
          },
          'metadata': <String, dynamic>{'api_version': '1.0'},
        }),
        data: <String, dynamic>{'intent': 'What dose of aspirin is safe?'},
      );

      final agents = AgentsClient(p2x);
      final r = await agents.processIntent(
        intent: 'What dose of aspirin is safe?',
      );
      expect(r['status'], 'success');
      // Public-route Bearer skip is covered in auth_interceptor_test.
    });
  });

  group('AgentsClient.create (full payload)', () {
    test('POSTs every optional field when supplied', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{'id': 'a-9'},
        }),
        data: <String, dynamic>{
          'name': 'Triage',
          'type': 'specialist',
          'description': 'd',
          'capabilities': <String>['calc'],
          'model': 'gpt',
          'temperature': 0.5,
          'max_tokens': 1024,
          'system_prompt': 'be helpful',
          'metadata': <String, dynamic>{'k': 'v'},
        },
      );
      final agents = AgentsClient(p2x);
      final r = await agents.create(
        name: 'Triage',
        type: 'specialist',
        description: 'd',
        capabilities: <String>['calc'],
        model: 'gpt',
        temperature: 0.5,
        maxTokens: 1024,
        systemPrompt: 'be helpful',
        metadata: <String, dynamic>{'k': 'v'},
      );
      expect(r['id'], 'a-9');
    });
  });

  group('AgentsClient.show / update / destroy', () {
    test('GETs /agents/{uuid}', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/agents/a-1',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{'id': 'a-1', 'name': 'A'},
        }),
      );
      final r = await AgentsClient(p2x).show(uuid: 'a-1');
      expect(r['name'], 'A');
    });

    test('PUT /agents/{uuid} rewrites to POST ?_method=PUT', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/a-1',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{'id': 'a-1', 'name': 'New'},
        }),
        data: <String, dynamic>{'name': 'New'},
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );
      final r = await AgentsClient(p2x).update(
        uuid: 'a-1',
        patch: <String, dynamic>{'name': 'New'},
      );
      expect(r['name'], 'New');
    });

    test('DELETE /agents/{uuid} completes', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onDelete(
        '/agents/a-1',
        (req) => req.reply(200, <String, dynamic>{'success': true}),
      );
      await expectLater(AgentsClient(p2x).destroy(uuid: 'a-1'), completes);
    });
  });

  group('AgentsClient.removeTool', () {
    test('DELETE /agents/{uuid}/tools/{tool} completes', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onDelete(
        '/agents/a-1/tools/calculator',
        (req) => req.reply(200, <String, dynamic>{'success': true}),
      );
      await expectLater(
        AgentsClient(p2x).removeTool(uuid: 'a-1', tool: 'calculator'),
        completes,
      );
    });
  });

  group('AgentsClient.resumeExecution / executions / statistics', () {
    test('POSTs /agents/resume-execution with execution_id + input', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/resume-execution',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{'execution_id': 99, 'status': 'running'},
        }),
        data: <String, dynamic>{
          'execution_id': 99,
          'input': <Map<String, dynamic>>[
            <String, dynamic>{'answer': 'yes'},
          ],
        },
      );
      final r = await AgentsClient(p2x).resumeExecution(
        executionId: 99,
        input: <Map<String, dynamic>>[
          <String, dynamic>{'answer': 'yes'},
        ],
      );
      expect(r['status'], 'running');
    });

    test('GETs /agents/{uuid}/executions as a list', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/agents/a-1/executions',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'execution_id': 1},
          ],
        }),
      );
      final list = await AgentsClient(p2x).executions(uuid: 'a-1');
      expect(list, hasLength(1));
    });

    test('GETs /agents/{uuid}/statistics as a map', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/agents/a-1/statistics',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{'runs': 42},
        }),
      );
      final r = await AgentsClient(p2x).statistics(uuid: 'a-1');
      expect(r['runs'], 42);
    });

    test('GETs /protocol/agents/all as a list', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/protocol/agents/all',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
          ],
        }),
      );
      final list = await AgentsClient(p2x).listAgentProtocols();
      expect(list, hasLength(2));
    });
  });

  group('AgentsClient intelligent (batch / entity / search / statistics)', () {
    test('POSTs /agents/intelligent/intent/batch', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/intelligent/intent/batch',
        (req) => req.reply(200, <String, dynamic>{'status': 'success'}),
        data: <String, dynamic>{
          'intents': <String>['a', 'b'],
        },
      );
      final r = await AgentsClient(p2x)
          .batchProcessIntent(intents: <String>['a', 'b']);
      expect(r['status'], 'success');
    });

    test('POSTs /agents/intelligent/entity/identify', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/intelligent/entity/identify',
        (req) => req.reply(200, <String, dynamic>{'status': 'success'}),
        data: <String, dynamic>{'entity': 'FDA'},
      );
      final r = await AgentsClient(p2x).identifyEntity(entity: 'FDA');
      expect(r['status'], 'success');
    });

    test('POSTs /agents/intelligent/search', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/agents/intelligent/search',
        (req) => req.reply(200, <String, dynamic>{'status': 'success'}),
        data: <String, dynamic>{
          'capability': 'billing',
          'agency': 'cms',
          'state': 'CA',
          'type': 'specialist',
          'limit': 5,
        },
      );
      final r = await AgentsClient(p2x).searchAgents(
        capability: 'billing',
        agency: 'cms',
        state: 'CA',
        type: 'specialist',
        limit: 5,
      );
      expect(r['status'], 'success');
    });

    test('GETs /agents/intelligent/statistics', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/agents/intelligent/statistics',
        (req) => req.reply(200, <String, dynamic>{'status': 'success'}),
      );
      final r = await AgentsClient(p2x).intelligentStatistics();
      expect(r['status'], 'success');
    });
  });

  // ─── resource owner wizard (Phase 3.J) ────────────────────────────────
  group('AgentsClient.createResourceListing', () {
    test('POSTs /wizard/resource-owner with owner + listing + auto_rules',
        () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 55,
            'status': 'draft',
            'subproject_id': 7,
          },
        }),
        data: <String, dynamic>{
          'owner': <String, dynamic>{'name': 'Jo', 'contact': 'jo@x.com'},
          'listing': <String, dynamic>{
            'listing_type': 'property',
            'name': 'Unit 4B',
            'description': 'A two-bed condo',
            'metadata': <String, dynamic>{'beds': 2},
          },
          'auto_rules': <String, dynamic>{'min_credit': 700},
        },
      );

      final agents = AgentsClient(p2x);
      final draft = await agents.createResourceListing(
        owner: <String, dynamic>{'name': 'Jo', 'contact': 'jo@x.com'},
        listing: <String, dynamic>{
          'listing_type': 'property',
          'name': 'Unit 4B',
          'description': 'A two-bed condo',
          'metadata': <String, dynamic>{'beds': 2},
        },
        autoRules: <String, dynamic>{'min_credit': 700},
      );
      expect(draft.resourceListingId, 55);
      expect(draft.status, 'draft');
      expect(draft.subprojectId, 7);
    });

    test('omits auto_rules when not supplied', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 56,
            'status': 'draft',
            'subproject_id': 7,
          },
        }),
        data: <String, dynamic>{
          'owner': <String, dynamic>{'name': 'Jo', 'contact': 'c'},
          'listing': <String, dynamic>{
            'listing_type': 'gig',
            'name': 'n',
            'description': 'd',
            'metadata': <String, dynamic>{},
          },
        },
      );
      final agents = AgentsClient(p2x);
      final draft = await agents.createResourceListing(
        owner: <String, dynamic>{'name': 'Jo', 'contact': 'c'},
        listing: <String, dynamic>{
          'listing_type': 'gig',
          'name': 'n',
          'description': 'd',
          'metadata': <String, dynamic>{},
        },
      );
      expect(draft.resourceListingId, 56);
    });

    test('attaches Authorization, X-Domain and Idempotency-Key headers',
        () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 1,
            'status': 'draft',
            'subproject_id': 7,
          },
        }),
        data: Matchers.any,
      );
      final resp = await p2x.dio.post<Map<String, dynamic>>(
        '/wizard/resource-owner',
        data: <String, dynamic>{'owner': <String, dynamic>{}},
      );
      final headers = resp.requestOptions.headers;
      expect(headers['Authorization'], 'Bearer tok-1');
      expect(headers['X-Domain'], 'phm.ai');
      expect(headers['Idempotency-Key'], isA<String>());
      expect((headers['Idempotency-Key'] as String).isNotEmpty, isTrue);
    });

    test('422 surfaces as ValidationException with field errors', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'listing.name': <String>['The listing.name field is required.'],
          },
        }),
        data: Matchers.any,
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.createResourceListing(
          owner: <String, dynamic>{'name': 'Jo', 'contact': 'c'},
          listing: <String, dynamic>{},
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['listing.name'],
            'listing.name errors',
            <String>['The listing.name field is required.'],
          ),
        ),
      );
    });

    test('401 throws UnauthorizedException and fires onUnauthorized',
        () async {
      var fired = 0;
      final p2x = _newClient(
        token: 'tok-1',
        domain: 'phm.ai',
        onUnauthorized: () => fired++,
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner',
        (req) => req.reply(401, <String, dynamic>{'message': 'Unauthenticated.'}),
        data: Matchers.any,
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.createResourceListing(
          owner: <String, dynamic>{},
          listing: <String, dynamic>{},
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(fired, 1);
    });
  });

  group('AgentsClient.activateResourceListing', () {
    test('POSTs /wizard/resource-owner/{id}/activate and decodes the agent',
        () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/55/activate',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 55,
            'agent_id': 900,
            'listing_status': 'active',
            'activated_at': '2026-06-15T09:00:00+00:00',
          },
        }),
      );
      final agents = AgentsClient(p2x);
      final act = await agents.activateResourceListing(listingId: 55);
      expect(act.resourceListingId, 55);
      expect(act.agentId, 900);
      expect(act.listingStatus, 'active');
      expect(act.activatedAt, isA<DateTime>());
    });

    test('422 (non-draft listing) surfaces as ValidationException', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/55/activate',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'Resource listing is not in draft status.',
          'errors': <String, dynamic>{
            'status': <String>['Only draft listings may be activated.'],
          },
        }),
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.activateResourceListing(listingId: 55),
        throwsA(isA<ValidationException>()),
      );
    });

    test('404 (cross-tenant listing) surfaces as NotFoundException', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/55/activate',
        (req) => req.reply(404, <String, dynamic>{
          'message': 'Resource listing not found in current tenant.',
        }),
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.activateResourceListing(listingId: 55),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('AgentsClient.claimResourceListing', () {
    test('POSTs /wizard/resource-owner/{id}/claim (fill) and decodes invite',
        () async {
      final p2x = _newClient(token: 'tok-worker', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 77,
            'listing_status': 'active',
            'wizard_invite_id': 1234,
            'role_id': 5,
            'protocol_id': 9,
          },
        }),
        data: <String, dynamic>{'rate_asked': 80},
      );
      final agents = AgentsClient(p2x);
      final claim = await agents.claimResourceListing(
        listingId: 77,
        rateAsked: 80,
      );
      expect(claim.resourceListingId, 77);
      expect(claim.wizardInviteId, 1234);
      expect(claim.roleId, 5);
      expect(claim.protocolId, 9);
      expect(claim.isEscalated, isFalse);
    });

    test('sends on_behalf_of_user_id for machine claim-back', () async {
      final p2x = _newClient(token: 'tok-machine', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 77,
            'listing_status': 'active',
            'wizard_invite_id': 1,
            'role_id': 5,
            'protocol_id': 9,
          },
        }),
        data: <String, dynamic>{'on_behalf_of_user_id': 4242},
      );
      final agents = AgentsClient(p2x);
      final claim = await agents.claimResourceListing(
        listingId: 77,
        onBehalfOfUserId: 4242,
      );
      expect(claim.resourceListingId, 77);
    });

    test('sends a null body when no optional fields supplied', () async {
      final p2x = _newClient(token: 'tok-worker', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 77,
            'listing_status': 'active',
            'wizard_invite_id': 1,
            'role_id': 5,
            'protocol_id': 9,
          },
        }),
      );
      final agents = AgentsClient(p2x);
      final claim = await agents.claimResourceListing(listingId: 77);
      expect(claim.wizardInviteId, 1);
    });

    test('202 escalate decodes with isEscalated true and null invite ids',
        () async {
      final p2x = _newClient(token: 'tok-worker', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(202, <String, dynamic>{
          'data': <String, dynamic>{
            'resource_listing_id': 77,
            'listing_status': 'active',
            'decision': 'escalate',
          },
          'message': 'Gig claim pending manual review by the listing owner.',
        }),
        data: Matchers.any,
      );
      final agents = AgentsClient(p2x);
      final claim = await agents.claimResourceListing(
        listingId: 77,
        rateAsked: 80,
      );
      expect(claim.isEscalated, isTrue);
      expect(claim.decision, 'escalate');
      expect(claim.wizardInviteId, isNull);
    });

    test('422 (auto-rules reject) surfaces as ValidationException', () async {
      final p2x = _newClient(token: 'tok-worker', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'Gig claim rejected by the listing auto-rules.',
          'errors': <String, dynamic>{
            'claim': <String>['The listing auto-rules rejected this claimant.'],
          },
        }),
        data: Matchers.any,
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.claimResourceListing(listingId: 77),
        throwsA(isA<ValidationException>()),
      );
    });

    test('404 (staffing v2 off / not claimable) surfaces as NotFoundException',
        () async {
      final p2x = _newClient(token: 'tok-worker', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/resource-owner/77/claim',
        (req) => req.reply(404, <String, dynamic>{
          'message': 'Resource listing not found in current tenant.',
        }),
        data: Matchers.any,
      );
      final agents = AgentsClient(p2x);
      await expectLater(
        agents.claimResourceListing(listingId: 77),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
