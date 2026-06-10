import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/agents_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
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
}
