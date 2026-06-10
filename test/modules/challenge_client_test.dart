import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:ycaas_flutter_sdk/src/modules/challenge_client.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

P2xClient _newClient() => P2xClient(
      config: const P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
      ),
    );

void main() {
  test('run POSTs /challenge/run', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/challenge/run',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'attached': true, 'id': 77},
      }),
      data: <String, dynamic>{
        'personal_chain_id': 12,
        'challenge_id': 5,
      },
    );
    final r = await ChallengeClient(p2x).run(personalChainId: 12, challengeId: 5);
    expect(r['id'], 77);
  });

  test('startTask POSTs /challenge/start-task', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onPost(
      '/challenge/start-task',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'started': true},
      }),
      data: <String, dynamic>{
        'attached_challenge_id': 77,
        'challenge_task_id': 1,
      },
    );
    final r = await ChallengeClient(p2x).startTask(
      attachedChallengeId: 77,
      challengeTaskId: 1,
    );
    expect(r['started'], isTrue);
  });

  test('getTypes GETs /challenge/get-types', () async {
    final p2x = _newClient();
    final adapter = DioAdapter(dio: p2x.dio);
    adapter.onGet(
      '/challenge/get-types',
      (req) => req.reply(200, <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'name': 'video'},
          <String, dynamic>{'id': 2, 'name': 'photo'},
        ],
      }),
    );
    final types = await ChallengeClient(p2x).getTypes();
    expect(types, hasLength(2));
  });
}
