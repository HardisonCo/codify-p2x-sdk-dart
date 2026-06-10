import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/referral_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

void main() {
  test('confirm POSTs /referral/confirm with destination', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/referral/confirm',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'success': true},
      }),
      data: <String, dynamic>{
        'id': 5,
        'chain_id': 12,
        'destination': 'agency-x',
      },
    );
    final r = await ReferralClient(p2x).confirm(
      id: 5,
      chainId: 12,
      destination: 'agency-x',
    );
    expect(r['success'], isTrue);
  });

  test('create POSTs /referral', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/referral',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'id': 1, 'title': 'PCP Referral'},
      }),
      data: <String, dynamic>{
        'title': 'PCP Referral',
        'referral_destinations': <String>['pcp', 'clinic-x'],
        'urgency_level': 'normal',
      },
    );
    final r = await ReferralClient(p2x).create(
      title: 'PCP Referral',
      referralDestinations: <String>['pcp', 'clinic-x'],
      urgencyLevel: 'normal',
    );
    expect(r['id'], 1);
  });
}
