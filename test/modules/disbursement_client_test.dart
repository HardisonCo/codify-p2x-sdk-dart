import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/disbursement_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

void main() {
  test('run hits /disbursement/run/{id}/{chain}', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onGet(
      '/disbursement/run/5/12',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'state': 'pending'},
      }),
    );
    final r = await DisbursementClient(p2x).run(disbursement: 5, chain: 12);
    expect(r['state'], 'pending');
  });

  test('confirm POSTs /disbursement/confirm with id + chain_id', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/disbursement/confirm',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'success': true},
      }),
      data: <String, dynamic>{'id': 5, 'chain_id': 12},
    );
    final r = await DisbursementClient(p2x).confirm(id: 5, chainId: 12);
    expect(r['success'], isTrue);
  });

  test('create POSTs /disbursement', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/disbursement',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'id': 99, 'title': 'Grant payout'},
      }),
      data: <String, dynamic>{
        'title': 'Grant payout',
        'disbursement_type': 'grant',
        'amount': 1000,
        'currency': 'USD',
      },
    );
    final r = await DisbursementClient(p2x).create(
      title: 'Grant payout',
      disbursementType: 'grant',
      amount: 1000,
      currency: 'USD',
    );
    expect(r['id'], 99);
  });
}
