// Contract tests for NioIntegrationsClient.
//
// Covers:
//   GET  /api/v1/integrations/nio/coins/balance  — current balance
//   POST /api/v1/integrations/nio/coins/spend    — server-authoritative spend
//   POST /api/v1/integrations/nio/coins/grant    — server-side grant

import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/integrations/nio_integrations_client.dart';
import 'package:codify_p2x_sdk/src/integrations/nio_integrations_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late NioIntegrationsClient nio;

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    nio = NioIntegrationsClient(base);
  });

  group('NioIntegrationsClient.balance', () {
    test('GETs /v1/integrations/nio/coins/balance and decodes CoinBalance',
        () async {
      adapter.onGet(
        '/v1/integrations/nio/coins/balance',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'balance': 120,
            'lifetime_earned': 200,
            'lifetime_spent': 80,
            'as_of': '2026-05-01T08:00:00Z',
          },
        }),
      );

      final b = await nio.balance();

      expect(b, isA<CoinBalance>());
      expect(b.balance, 120);
      expect(b.lifetimeEarned, 200);
      expect(b.lifetimeSpent, 80);
      expect(b.asOf, DateTime.parse('2026-05-01T08:00:00Z'));
    });
  });

  group('NioIntegrationsClient.spend', () {
    test('POSTs /v1/integrations/nio/coins/spend and returns CoinTransaction',
        () async {
      adapter.onPost(
        '/v1/integrations/nio/coins/spend',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 17,
            'type': 'spend',
            'amount': 10,
            'reason': 'meal-plan-unlock',
            'balance_after': 110,
            'created_at': '2026-05-01T08:00:00Z',
            'metadata': <String, dynamic>{'meal_plan_id': 42},
          },
        }),
        data: Matchers.any,
      );

      final tx = await nio.spend(
        amount: 10,
        reason: 'meal-plan-unlock',
        metadata: <String, dynamic>{'meal_plan_id': 42},
      );

      expect(tx, isA<CoinTransaction>());
      expect(tx.id, 17);
      expect(tx.type, 'spend');
      expect(tx.amount, 10);
      expect(tx.reason, 'meal-plan-unlock');
      expect(tx.balanceAfter, 110);
      expect(tx.metadata['meal_plan_id'], 42);
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/v1/integrations/nio/coins/spend',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 1,
            'type': 'spend',
            'amount': 1,
            'reason': 'r',
            'balance_after': 0,
            'created_at': '2026-05-01T08:00:00Z',
          },
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/v1/integrations/nio/coins/spend',
        data: <String, dynamic>{},
        options: NioIntegrationsClient.idempotencyOptionsForTest(
          'spend-uuid-1',
        ),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'spend-uuid-1');
    });
  });

  group('NioIntegrationsClient.grant', () {
    test('POSTs /v1/integrations/nio/coins/grant and returns CoinTransaction',
        () async {
      adapter.onPost(
        '/v1/integrations/nio/coins/grant',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 18,
            'type': 'grant',
            'amount': 5,
            'reason': 'ad-watched',
            'balance_after': 115,
            'created_at': '2026-05-01T08:00:00Z',
          },
        }),
        data: Matchers.any,
      );

      final tx = await nio.grant(amount: 5, reason: 'ad-watched');

      expect(tx, isA<CoinTransaction>());
      expect(tx.id, 18);
      expect(tx.type, 'grant');
      expect(tx.amount, 5);
      expect(tx.reason, 'ad-watched');
      expect(tx.balanceAfter, 115);
    });

    test('forwards Idempotency-Key header when caller supplies one', () async {
      adapter.onPost(
        '/v1/integrations/nio/coins/grant',
        (req) => req.reply(201, <String, dynamic>{
          'data': <String, dynamic>{
            'id': 1,
            'type': 'grant',
            'amount': 1,
            'reason': 'r',
            'balance_after': 1,
            'created_at': '2026-05-01T08:00:00Z',
          },
        }),
        data: Matchers.any,
      );

      final resp = await base.dio.post<dynamic>(
        '/v1/integrations/nio/coins/grant',
        data: <String, dynamic>{},
        options: NioIntegrationsClient.idempotencyOptionsForTest(
          'grant-uuid-1',
        ),
      );

      expect(resp.requestOptions.headers['Idempotency-Key'], 'grant-uuid-1');
    });
  });
}
