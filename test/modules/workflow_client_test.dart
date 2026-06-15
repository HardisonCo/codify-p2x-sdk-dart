import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/workflow_client.dart';
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
  group('WorkflowClient.startPipeline', () {
    test('POSTs /workflow/codify-pipeline/start with problem + session', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/workflow/codify-pipeline/start',
        (req) => req.reply(200, <String, dynamic>{
          'started': true,
          'progress': 5,
          'interaction': 'question',
          'name': 'patient drug review',
          'interaction_data': <String, dynamic>{},
        }),
        data: <String, dynamic>{
          'session': 'sess-12345',
          'timezone': 'UTC',
          'problem': 'Patient drug review',
        },
      );

      final wf = WorkflowClient(p2x);
      final r = await wf.startPipeline(
        session: 'sess-12345',
        timezone: 'UTC',
        problem: 'Patient drug review',
      );
      expect(r['started'], isTrue);
      expect(r['progress'], 5);
    });

    test('POSTs /workflow/codify-pipeline/start with a url input', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/workflow/codify-pipeline/start',
        (req) => req.reply(200, <String, dynamic>{'started': true}),
        data: <String, dynamic>{
          'session': 'sess-url',
          'timezone': 'UTC',
          'url': 'https://example.com/spec.pdf',
        },
      );
      final wf = WorkflowClient(p2x);
      final r = await wf.startPipeline(
        session: 'sess-url',
        timezone: 'UTC',
        url: 'https://example.com/spec.pdf',
      );
      expect(r['started'], isTrue);
    });

    // Public-route Bearer skip is covered in
    // test/client/interceptors/auth_interceptor_test.dart.
  });

  group('WorkflowClient.stopPipeline', () {
    test('GETs /workflow/codify-pipeline/stop/{session}', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/workflow/codify-pipeline/stop/sess-12345',
        (req) => req.reply(200, <String, dynamic>{
          'finished': true,
          'progress': 100,
        }),
      );
      final wf = WorkflowClient(p2x);
      final r = await wf.stopPipeline(session: 'sess-12345');
      expect(r['finished'], isTrue);
    });
  });

  group('WorkflowClient.listWorkflowProtocols', () {
    test('GETs /protocol/workflow/all as a list', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/protocol/workflow/all',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
            <String, dynamic>{'id': 3},
          ],
        }),
      );
      final wf = WorkflowClient(p2x);
      expect(await wf.listWorkflowProtocols(), hasLength(3));
    });

    test('returns empty list when data is absent', () async {
      final p2x = _newClient(token: 'tok-1', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/protocol/workflow/all',
        (req) => req.reply(200, <String, dynamic>{}),
      );
      final wf = WorkflowClient(p2x);
      expect(await wf.listWorkflowProtocols(), isEmpty);
    });
  });

  group('WorkflowClient.checkPipeline', () {
    test('GETs /workflow/codify-pipeline/check-pipeline/{session}', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/workflow/codify-pipeline/check-pipeline/sess-12345',
        (req) => req.reply(200, <String, dynamic>{
          'finished': false,
          'progress': 50,
          'interaction': 'question',
        }),
      );
      final wf = WorkflowClient(p2x);
      final r = await wf.checkPipeline(session: 'sess-12345');
      expect(r['progress'], 50);
    });
  });

  group('WorkflowClient.saveResponse', () {
    test('POSTs /workflow/codify-pipeline/save-response', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/workflow/codify-pipeline/save-response',
        (req) => req.reply(200, <String, dynamic>{
          'finished': false,
          'progress': 70,
        }),
        data: <String, dynamic>{
          'session': 'sess-12345',
          'question': 'budget?',
          'answer': '5000',
        },
      );
      final wf = WorkflowClient(p2x);
      final r = await wf.saveResponse(
        session: 'sess-12345',
        question: 'budget?',
        answer: '5000',
      );
      expect(r['progress'], 70);
    });
  });

  group('WorkflowClient.invokePipe', () {
    test('POSTs /pipes/invoke and returns the flat shape', () async {
      final p2x = _newClient(token: 'tok-1');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/pipes/invoke',
        (req) => req.reply(200, <String, dynamic>{
          'ok': true,
          'pipe_name': 'lookup',
          'subproject_id': 7,
          'domain': 'phm.ai',
          'result': <String, dynamic>{'matches': <dynamic>[]},
        }),
        data: <String, dynamic>{
          'pipe_name': 'lookup',
          'subproject_id': 7,
          'domain': 'phm.ai',
          'params': <String, dynamic>{'q': 'aspirin'},
        },
      );

      final wf = WorkflowClient(p2x);
      final r = await wf.invokePipe(
        pipeName: 'lookup',
        subprojectId: 7,
        domain: 'phm.ai',
        params: <String, dynamic>{'q': 'aspirin'},
      );
      expect(r['ok'], isTrue);
      expect(r['result'], isA<Map<String, dynamic>>());
    });
  });

  // ─── admin pipe-config CRUD (SuperAdmin) ──────────────────────────────
  Map<String, dynamic> _pipeConfigRow({
    int id = 1,
    int subprojectId = 7,
    String pipeName = 'LocateResource',
    String? providerClass = 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
    bool isActive = true,
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': subprojectId,
        'canonical_pipe_id': 3,
        'pipe_name': pipeName,
        'provider_class': providerClass,
        'settings': <String, dynamic>{'mode': 'fast'},
        'is_active': isActive,
        'effective_from': '2026-06-01T08:00:00+00:00',
        'created_at': '2026-06-01T08:00:00+00:00',
        'updated_at': '2026-06-01T08:00:00+00:00',
      };

  group('WorkflowClient.listPipeConfigs', () {
    test('GETs /admin/subproject/{id}/pipe-config and decodes the rows',
        () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            _pipeConfigRow(),
            _pipeConfigRow(id: 2, pipeName: 'CodifyDeal'),
          ],
        }),
      );

      final wf = WorkflowClient(p2x);
      final rows = await wf.listPipeConfigs(subprojectId: 7);
      expect(rows, hasLength(2));
      expect(rows.first.id, 1);
      expect(rows.first.pipeName, 'LocateResource');
      expect(rows.first.subprojectId, 7);
      expect(rows.first.settings['mode'], 'fast');
      expect(rows.first.isActive, isTrue);
      expect(rows.first.effectiveFrom, isA<DateTime>());
      expect(rows[1].pipeName, 'CodifyDeal');
    });

    test('attaches Authorization + X-Domain headers', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(200, <String, dynamic>{'data': <dynamic>[]}),
      );

      final resp = await p2x.dio.get<Map<String, dynamic>>(
        '/admin/subproject/7/pipe-config',
      );
      final headers = resp.requestOptions.headers;
      expect(headers['Authorization'], 'Bearer tok-admin');
      expect(headers['X-Domain'], 'phm.ai');
      // GET carries no Idempotency-Key.
      expect(headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('returns empty list when data is absent', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(200, <String, dynamic>{}),
      );
      final wf = WorkflowClient(p2x);
      expect(await wf.listPipeConfigs(subprojectId: 7), isEmpty);
    });

    test('401 throws UnauthorizedException and fires onUnauthorized',
        () async {
      var fired = 0;
      final p2x = _newClient(
        token: 'tok-admin',
        domain: 'phm.ai',
        onUnauthorized: () => fired++,
      );
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(401, <String, dynamic>{'message': 'Unauthenticated.'}),
      );
      final wf = WorkflowClient(p2x);
      await expectLater(
        wf.listPipeConfigs(subprojectId: 7),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(fired, 1);
    });
  });

  group('WorkflowClient.createPipeConfig', () {
    test('POSTs the override body and decodes the 201 row', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(201, <String, dynamic>{'data': _pipeConfigRow()}),
        data: <String, dynamic>{
          'pipe_name': 'LocateResource',
          'provider_class': 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
          'settings': <String, dynamic>{'mode': 'fast'},
          'is_active': true,
        },
      );

      final wf = WorkflowClient(p2x);
      final row = await wf.createPipeConfig(
        subprojectId: 7,
        pipeName: 'LocateResource',
        providerClass: 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
        settings: <String, dynamic>{'mode': 'fast'},
        isActive: true,
      );
      expect(row.id, 1);
      expect(row.pipeName, 'LocateResource');
      expect(row.providerClass, 'Modules\\Workflow\\Pipes\\LocateResourcePipe');
    });

    test('omits optional fields when not supplied', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(201, <String, dynamic>{'data': _pipeConfigRow()}),
        data: <String, dynamic>{
          'pipe_name': 'LocateResource',
          'provider_class': 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
        },
      );
      final wf = WorkflowClient(p2x);
      final row = await wf.createPipeConfig(
        subprojectId: 7,
        pipeName: 'LocateResource',
        providerClass: 'Modules\\Workflow\\Pipes\\LocateResourcePipe',
      );
      expect(row.id, 1);
    });

    test('attaches an Idempotency-Key on the write', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(201, <String, dynamic>{'data': _pipeConfigRow()}),
        data: Matchers.any,
      );
      final resp = await p2x.dio.post<Map<String, dynamic>>(
        '/admin/subproject/7/pipe-config',
        data: <String, dynamic>{'pipe_name': 'x', 'provider_class': 'y'},
      );
      final headers = resp.requestOptions.headers;
      expect(headers['Idempotency-Key'], isA<String>());
      expect((headers['Idempotency-Key'] as String).isNotEmpty, isTrue);
      expect(headers['Authorization'], 'Bearer tok-admin');
      expect(headers['X-Domain'], 'phm.ai');
    });

    test('422 (duplicate override) surfaces as ValidationException', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'pipe_name': <String>['An override for this pipe already exists.'],
          },
        }),
        data: Matchers.any,
      );
      final wf = WorkflowClient(p2x);
      await expectLater(
        wf.createPipeConfig(
          subprojectId: 7,
          pipeName: 'LocateResource',
          providerClass: 'X',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['pipe_name'],
            'pipe_name errors',
            <String>['An override for this pipe already exists.'],
          ),
        ),
      );
    });
  });

  group('WorkflowClient.updatePipeConfig', () {
    test('rewrites PATCH to POST ?_method=PATCH and sends the body', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config/1',
        (req) => req.reply(200, <String, dynamic>{
          'data': _pipeConfigRow(isActive: false),
        }),
        data: <String, dynamic>{'is_active': false},
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );
      final wf = WorkflowClient(p2x);
      final row = await wf.updatePipeConfig(
        subprojectId: 7,
        id: 1,
        isActive: false,
      );
      expect(row.isActive, isFalse);
    });

    test('clearProviderClass sends an explicit null provider_class', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config/1',
        (req) => req.reply(200, <String, dynamic>{
          'data': _pipeConfigRow(providerClass: null),
        }),
        data: <String, dynamic>{'provider_class': null},
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );
      final wf = WorkflowClient(p2x);
      final row = await wf.updatePipeConfig(
        subprojectId: 7,
        id: 1,
        clearProviderClass: true,
      );
      expect(row.providerClass, isNull);
    });

    test('404 surfaces as NotFoundException', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/admin/subproject/7/pipe-config/99',
        (req) => req.reply(404, <String, dynamic>{'message': 'Pipe config not found'}),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PATCH'},
      );
      final wf = WorkflowClient(p2x);
      await expectLater(
        wf.updatePipeConfig(subprojectId: 7, id: 99, isActive: true),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('WorkflowClient.deletePipeConfig', () {
    test('DELETEs the row and returns true', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onDelete(
        '/admin/subproject/7/pipe-config/1',
        (req) => req.reply(200, <String, dynamic>{'deleted': true}),
      );
      final wf = WorkflowClient(p2x);
      expect(await wf.deletePipeConfig(subprojectId: 7, id: 1), isTrue);
    });

    test('404 surfaces as NotFoundException', () async {
      final p2x = _newClient(token: 'tok-admin', domain: 'phm.ai');
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onDelete(
        '/admin/subproject/7/pipe-config/99',
        (req) => req.reply(404, <String, dynamic>{'message': 'not found'}),
      );
      final wf = WorkflowClient(p2x);
      await expectLater(
        wf.deletePipeConfig(subprojectId: 7, id: 99),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
