import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/workflow_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient({String? token}) => P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: token == null ? null : () => token,
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

    // Public-route Bearer skip is covered in
    // test/client/interceptors/auth_interceptor_test.dart.
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
}
