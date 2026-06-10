import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/wizard/wizard_models.dart';

void main() {
  group('WizardStartResponse.fromJson', () {
    test('reads deal_id, state, protocol_id and stashes the rest', () {
      final r = WizardStartResponse.fromJson(<String, dynamic>{
        'deal_id': 42,
        'state': 'analyzing',
        'protocol_id': 7,
        'metadata': <String, dynamic>{'name': 'A'},
        'extra': 'value',
      });
      expect(r.dealId, 42);
      expect(r.state, 'analyzing');
      expect(r.protocolId, 7);
      expect(r.extras['metadata'], isA<Map<String, dynamic>>());
      expect(r.extras['extra'], 'value');
    });

    test('tolerates missing protocol_id', () {
      final r = WizardStartResponse.fromJson(<String, dynamic>{
        'deal_id': 1,
        'state': 'analyzing',
      });
      expect(r.protocolId, isNull);
    });

    test('accepts dealId/protocolId camelCase as fallback', () {
      final r = WizardStartResponse.fromJson(<String, dynamic>{
        'dealId': 99,
        'protocolId': 11,
        'state': 'codified',
      });
      expect(r.dealId, 99);
      expect(r.protocolId, 11);
    });
  });
}
