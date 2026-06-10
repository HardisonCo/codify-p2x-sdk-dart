// Contract tests for WizardClient — the YCaaS Five-Step Wizard surface.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/wizard/wizard_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

void main() {
  group('WizardClient.start', () {
    test('POSTs /wizard/start with problem + metadata, returns deal_id', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/start',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'deal_id': 4242,
            'state': 'analyzing',
            'protocol_id': 7,
            'metadata': <String, dynamic>{'name': 'Patient drug review'},
          },
        }),
        data: <String, dynamic>{
          'problem': 'Need a medication reconciliation flow',
          'metadata': <String, dynamic>{'name': 'Patient drug review'},
        },
      );

      final wizard = WizardClient(p2x);
      final r = await wizard.start(
        problem: 'Need a medication reconciliation flow',
        metadata: <String, dynamic>{'name': 'Patient drug review'},
      );

      expect(r.dealId, 4242);
      expect(r.state, 'analyzing');
      expect(r.protocolId, 7);
      expect(r.extras['metadata'], isA<Map<String, dynamic>>());
    });
  });

  group('WizardClient.getState', () {
    test('GETs /wizard/get-state/{protocol} and returns the data map', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/wizard/get-state/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'state': 'codified', 'step': 2},
        }),
      );

      final wizard = WizardClient(p2x);
      final state = await wizard.getState(protocol: 7);

      expect(state['state'], 'codified');
      expect(state['step'], 2);
    });
  });

  group('WizardClient.codify', () {
    test('POSTs /wizard/codify/{protocol} with optional payload', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/codify/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'state': 'codified'},
        }),
        data: <String, dynamic>{'extra': 'value'},
      );

      final wizard = WizardClient(p2x);
      final result = await wizard.codify(
        protocol: 7,
        payload: <String, dynamic>{'extra': 'value'},
      );
      expect(result['state'], 'codified');
    });
  });

  group('WizardClient.setFinances', () {
    test('POSTs /wizard/set-finances/{protocol} with payload', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/set-finances/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'budget': 5000, 'currency': 'USD'},
        }),
        data: <String, dynamic>{'budget': 5000, 'currency': 'USD'},
      );

      final wizard = WizardClient(p2x);
      final r = await wizard.setFinances(
        protocol: 7,
        payload: <String, dynamic>{'budget': 5000, 'currency': 'USD'},
      );
      expect(r['budget'], 5000);
    });

    test('422 → ValidationException', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/set-finances/7',
        (req) => req.reply(422, <String, dynamic>{
          'success': false,
          'message': 'validation failed',
          'errors': <String, dynamic>{
            'budget': <String>['Budget is required.'],
          },
        }),
        data: <String, dynamic>{'currency': 'USD'},
      );

      final wizard = WizardClient(p2x);
      await expectLater(
        wizard.setFinances(
          protocol: 7,
          payload: <String, dynamic>{'currency': 'USD'},
        ),
        throwsA(
          anyOf(isA<ValidationException>(), isA<DioException>()),
        ),
      );
    });
  });

  group('WizardClient.findMembers', () {
    test('POSTs /wizard/find-members with search and returns a list', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/find-members',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'name': 'Alice'},
            <String, dynamic>{'id': 2, 'name': 'Bob'},
          ],
        }),
        data: <String, dynamic>{'search': 'ali'},
      );

      final wizard = WizardClient(p2x);
      final members = await wizard.findMembers(search: 'ali');
      expect(members.length, 2);
    });
  });

  group('WizardClient.validateEmail', () {
    test('POSTs /wizard/validate-email and returns the bool', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/validate-email',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'valid': true},
        }),
        data: <String, dynamic>{'email': 'x@y.com'},
      );

      final wizard = WizardClient(p2x);
      expect(await wizard.validateEmail(email: 'x@y.com'), isTrue);
    });
  });

  group('WizardClient.connectStripe', () {
    test('GETs /wizard/connect-stripe/{protocol} and returns the URL', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/wizard/connect-stripe/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{
            'url': 'https://connect.stripe.com/oauth/v2/authorize?…',
          },
        }),
      );

      final wizard = WizardClient(p2x);
      final url = await wizard.connectStripe(protocol: 7);
      expect(url, startsWith('https://connect.stripe.com'));
    });
  });

  group('WizardClient.publishProgram', () {
    test('POSTs /wizard/publish-program/{protocol} with settings', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onPost(
        '/wizard/publish-program/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'state': 'published'},
        }),
        data: <String, dynamic>{'visibility': 'public'},
      );

      final wizard = WizardClient(p2x);
      final r = await wizard.publishProgram(
        protocol: 7,
        settings: <String, dynamic>{'visibility': 'public'},
      );
      expect(r['state'], 'published');
    });
  });

  group('WizardClient.getFinalizationState', () {
    test('GETs /wizard/finalization-state/{protocol}', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/wizard/finalization-state/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'finalized': true, 'progress': 100},
        }),
      );

      final wizard = WizardClient(p2x);
      final r = await wizard.getFinalizationState(protocol: 7);
      expect(r['finalized'], isTrue);
      expect(r['progress'], 100);
    });
  });

  group('WizardClient.stepBack', () {
    test('GETs /wizard/step-back/{protocol}', () async {
      final p2x = _newClient();
      final adapter = DioAdapter(dio: p2x.dio);
      adapter.onGet(
        '/wizard/step-back/7',
        (req) => req.reply(200, <String, dynamic>{
          'success': true,
          'message': 'ok',
          'data': <String, dynamic>{'state': 'analyzing'},
        }),
      );

      final wizard = WizardClient(p2x);
      final r = await wizard.stepBack(protocol: 7);
      expect(r['state'], 'analyzing');
    });
  });
}
