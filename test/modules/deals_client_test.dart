import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/deals_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

Map<String, dynamic> _dealJson({
  int id = 1,
  String state = 'analyzing',
  String problem = 'Medication review',
}) =>
    <String, dynamic>{
      'id': id,
      'state': state,
      'problem': problem,
      'solutions': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Option A'},
        <String, dynamic>{'name': 'Option B'},
      ],
    };

void main() {
  group('DealsClient.define', () {
    test('POSTs /wizard/deal/define with statement', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/deal/define',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _dealJson(),
        }),
        data: <String, dynamic>{'statement': 'Medication review'},
      );

      final deals = DealsClient(p2x);
      final d = await deals.define(statement: 'Medication review');
      expect(d.id, 1);
      expect(d.state, 'analyzing');
      expect(d.extras['solutions'], isA<List<dynamic>>());
    });
  });

  group('DealsClient.status', () {
    test('GETs /wizard/deal/{id}/status', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/wizard/deal/42/status',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _dealJson(id: 42, state: 'setup'),
        }),
      );

      final deals = DealsClient(p2x);
      final d = await deals.status(dealId: 42);
      expect(d.id, 42);
      expect(d.state, 'setup');
    });
  });

  group('DealsClient.codify', () {
    test('POSTs /wizard/deal/{id}/codify with empty body', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/deal/42/codify',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _dealJson(id: 42, state: 'codified'),
        }),
        data: null,
      );

      final deals = DealsClient(p2x);
      final d = await deals.codify(dealId: 42);
      expect(d.state, 'codified');
    });
  });

  group('DealsClient.selectSolution', () {
    test('POSTs /wizard/deal/{id}/select-solution with idx', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/deal/42/select-solution',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': _dealJson(id: 42, state: 'codified'),
        }),
        data: <String, dynamic>{'solution_idx': 0},
      );

      final deals = DealsClient(p2x);
      final d = await deals.selectSolution(dealId: 42, solutionIdx: 0);
      expect(d.id, 42);
    });
  });

  group('DealsClient.setup + start + verify', () {
    test('lifecycle calls hit the right routes', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter
        ..onPost(
          '/wizard/deal/42/setup',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': _dealJson(id: 42, state: 'setup'),
          }),
          data: null,
        )
        ..onPost(
          '/wizard/deal/42/start',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': _dealJson(id: 42, state: 'executing'),
          }),
          data: null,
        )
        ..onPost(
          '/wizard/deal/42/verify/9',
          (req) => req.reply(200, <String, dynamic>{
            'success': true,
            'message': 'ok',
            'data': <String, dynamic>{
              'id': 42,
              'state': 'completed',
              'problem': 'Medication review',
              'outcome_class': 'success',
              'outcome_score': 0.92,
            },
          }),
          data: null,
        );

      final deals = DealsClient(p2x);
      expect((await deals.setup(dealId: 42)).state, 'setup');
      expect((await deals.start(dealId: 42)).state, 'executing');
      final verified = await deals.verify(dealId: 42, executionId: 9);
      expect(verified.outcomeClass, 'success');
      expect(verified.outcomeScore, 0.92);
    });
  });

  group('DealsClient.claimStep', () {
    test('POSTs /deals/{id}/steps/{idx}/claim', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/deals/42/steps/0/claim',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'claimed': true, 'claim_token': 't-1'},
        }),
        data: null,
      );

      final deals = DealsClient(p2x);
      final r = await deals.claimStep(dealId: 42, stepIdx: 0);
      expect(r['claimed'], isTrue);
      expect(r['claim_token'], 't-1');
    });
  });
}
