import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/report_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

void main() {
  test('submit POSTs /report/submit', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/report/submit',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'success': true},
      }),
      data: <String, dynamic>{
        'id': 5,
        'chain_id': 12,
        'fields': <String, dynamic>{'patient_count': 42},
      },
    );
    final r = await ReportClient(p2x).submit(
      id: 5,
      chainId: 12,
      fields: <String, dynamic>{'patient_count': 42},
    );
    expect(r['success'], isTrue);
  });

  test('create POSTs /report', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/report',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'id': 1, 'title': 'Monthly Census'},
      }),
      data: <String, dynamic>{
        'title': 'Monthly Census',
        'report_type': 'census',
        'template_fields': <String>['patient_count', 'avg_los'],
        'reporting_frequency': 'monthly',
      },
    );
    final r = await ReportClient(p2x).create(
      title: 'Monthly Census',
      reportType: 'census',
      templateFields: <String>['patient_count', 'avg_los'],
      reportingFrequency: 'monthly',
    );
    expect(r['id'], 1);
  });
}
