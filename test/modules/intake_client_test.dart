// Contract tests for IntakeClient.
//
// Mirrors the TS IntakeModuleApiClient (v1.4.0):
//   POST /api/v1/intake/start                              (public)
//   POST /api/v1/intake/handoff/{token}/exchange           (public)
//   POST /api/v1/intake/{intake}/voice-record
//   POST /api/v1/intake/{intake}/voice-finalize
//   POST /api/v1/intake/{intake}/answers
//   POST /api/v1/intake/{intake}/audience
//   POST /api/v1/intake/{intake}/handoff
//   GET  /api/v1/intake/{intake}/status

import 'package:ycaas_flutter_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/exceptions/validation_exception.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client.dart';
import 'package:ycaas_flutter_sdk/src/client/p2x_client_config.dart';
import 'package:ycaas_flutter_sdk/src/modules/intake_client.dart';
import 'package:ycaas_flutter_sdk/src/modules/intake_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Lower-case UUID v4 regex (Idempotency-Key auto-generation contract).
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late P2xClient base;
  late DioAdapter adapter;
  late IntakeClient client;

  Map<String, dynamic> sampleIntake({
    String id = 'intake_abc',
    String status = 'open',
    String? audience,
    Map<String, dynamic>? answers,
    String? voiceUrl,
    int? voiceDurationSeconds,
  }) =>
      <String, dynamic>{
        'id': id,
        'subproject_id': 'sp_crohnie',
        if (audience != null) 'audience': audience,
        'answers': answers ?? <String, dynamic>{},
        if (voiceUrl != null) 'voice_url': voiceUrl,
        if (voiceDurationSeconds != null)
          'voice_duration_seconds': voiceDurationSeconds,
        'status': status,
        'created_at': '2026-05-15T08:00:00Z',
        'updated_at': '2026-05-15T08:00:00Z',
      };

  Map<String, dynamic> sampleHandoff({
    String token = 'hndf_xyz',
    Map<String, dynamic>? intake,
  }) =>
      <String, dynamic>{
        'token': token,
        'expires_at': '2026-05-15T09:00:00Z',
        'target_subproject_domain': 'ibd.codifyhq.com',
        'exchange_url':
            'https://api.project20x.com/api/v1/intake/handoff/$token/exchange',
        if (intake != null) 'intake': intake,
      };

  setUp(() {
    base = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getToken: () => 'tok-abc',
        getDomain: () => 'crohnie.ai',
      ),
    );
    adapter = DioAdapter(dio: base.dio);
    client = IntakeClient(base);
  });

  group('IntakeClient.start', () {
    test('POSTs /v1/intake/start and returns the new Intake', () async {
      adapter.onPost(
        '/v1/intake/start',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleIntake(),
        }),
        data: Matchers.any,
      );

      final intake = await client.start();
      expect(intake, isA<Intake>());
      expect(intake.id, 'intake_abc');
      expect(intake.status, 'open');
    });

    test('forwards audienceHint and metadata in body', () async {
      adapter.onPost(
        '/v1/intake/start',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleIntake(audience: 'patient'),
        }),
        data: <String, dynamic>{
          'audience_hint': 'patient',
          'metadata': <String, dynamic>{'source': 'web'},
        },
      );

      final intake = await client.start(
        audienceHint: 'patient',
        metadata: const <String, dynamic>{'source': 'web'},
      );
      expect(intake.audience, 'patient');
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/start',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleIntake(),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.start();

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.exchange', () {
    test(
      'POSTs /v1/intake/handoff/<token>/exchange and returns IntakeHandoff '
      'with a materialised intake',
      () async {
        adapter.onPost(
          '/v1/intake/handoff/hndf_xyz/exchange',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleHandoff(
              intake: sampleIntake(status: 'handed_off'),
            ),
          }),
          data: Matchers.any,
        );

        final handoff = await client.exchange(token: 'hndf_xyz');
        expect(handoff.token, 'hndf_xyz');
        expect(handoff.intake, isNotNull);
        expect(handoff.intake!.status, 'handed_off');
      },
    );

    test('exchange request has NO Authorization header', () async {
      adapter.onPost(
        '/v1/intake/handoff/hndf_xyz/exchange',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleHandoff(intake: sampleIntake(status: 'handed_off')),
        }),
        data: Matchers.any,
      );

      Map<String, dynamic>? capturedHeaders;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedHeaders = Map<String, dynamic>.from(options.headers);
            handler.next(options);
          },
        ),
      );

      await client.exchange(token: 'hndf_xyz');

      expect(capturedHeaders, isNotNull);
      expect(capturedHeaders!.containsKey('Authorization'), isFalse);
    });
  });

  group('IntakeClient.voiceRecord', () {
    test(
      'POSTs /v1/intake/<id>/voice-record with audio_url + '
      'duration_seconds and returns the updated Intake',
      () async {
        adapter.onPost(
          '/v1/intake/intake_abc/voice-record',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleIntake(
              status: 'voice_pending',
              voiceUrl: 'https://cdn.x/voice.m4a',
              voiceDurationSeconds: 95,
            ),
          }),
          data: <String, dynamic>{
            'audio_url': 'https://cdn.x/voice.m4a',
            'duration_seconds': 95,
          },
        );

        final updated = await client.voiceRecord(
          'intake_abc',
          audioUrl: 'https://cdn.x/voice.m4a',
          duration: const Duration(minutes: 1, seconds: 35),
        );

        expect(updated.voiceUrl, 'https://cdn.x/voice.m4a');
        expect(updated.voiceDurationSeconds, 95);
        expect(updated.status, 'voice_pending');
      },
    );

    test('serializes duration via inSeconds (int, not ISO-8601)', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/voice-record',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(
            voiceUrl: 'https://cdn.x/v.m4a',
            voiceDurationSeconds: 42,
          ),
        }),
        data: <String, dynamic>{
          'audio_url': 'https://cdn.x/v.m4a',
          'duration_seconds': 42,
        },
      );

      final updated = await client.voiceRecord(
        'intake_abc',
        audioUrl: 'https://cdn.x/v.m4a',
        duration: const Duration(seconds: 42),
      );
      expect(updated.voiceDurationSeconds, 42);
    });

    test('forwards transcript when provided', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/voice-record',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(
            voiceUrl: 'https://cdn.x/v.m4a',
            voiceDurationSeconds: 42,
          ),
        }),
        data: <String, dynamic>{
          'audio_url': 'https://cdn.x/v.m4a',
          'duration_seconds': 42,
          'transcript': 'Local transcript.',
        },
      );

      await client.voiceRecord(
        'intake_abc',
        audioUrl: 'https://cdn.x/v.m4a',
        duration: const Duration(seconds: 42),
        transcript: 'Local transcript.',
      );
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/voice-record',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(
            voiceUrl: 'https://cdn.x/voice.m4a',
            voiceDurationSeconds: 42,
          ),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.voiceRecord(
        'intake_abc',
        audioUrl: 'https://cdn.x/voice.m4a',
        duration: const Duration(seconds: 42),
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.voiceFinalize', () {
    test(
      'POSTs /v1/intake/<id>/voice-finalize and returns the updated Intake',
      () async {
        adapter.onPost(
          '/v1/intake/intake_abc/voice-finalize',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleIntake(status: 'voice_pending'),
          }),
          data: Matchers.any,
        );

        final updated = await client.voiceFinalize('intake_abc');
        expect(updated.status, 'voice_pending');
      },
    );

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/voice-finalize',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(status: 'voice_pending'),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.voiceFinalize('intake_abc');

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.submitAnswers', () {
    test(
      'POSTs /v1/intake/<id>/answers with answers body and returns the '
      'updated Intake',
      () async {
        adapter.onPost(
          '/v1/intake/intake_abc/answers',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleIntake(
              status: 'in_progress',
              answers: <String, dynamic>{'q1': 'yes'},
            ),
          }),
          data: <String, dynamic>{
            'answers': <String, dynamic>{'q1': 'yes'},
          },
        );

        final updated = await client.submitAnswers(
          'intake_abc',
          answers: const <String, dynamic>{'q1': 'yes'},
        );

        expect(updated.status, 'in_progress');
        expect(updated.answers['q1'], 'yes');
      },
    );

    test('throws ValidationException on 422 when answers is empty', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/answers',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'answers': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.submitAnswers(
          'intake_abc',
          answers: const <String, dynamic>{},
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/answers',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(
            status: 'in_progress',
            answers: <String, dynamic>{'q1': 'yes'},
          ),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.submitAnswers(
        'intake_abc',
        answers: const <String, dynamic>{'q1': 'yes'},
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.setAudience', () {
    test(
      'POSTs /v1/intake/<id>/audience with audience and returns the '
      'updated Intake',
      () async {
        adapter.onPost(
          '/v1/intake/intake_abc/audience',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleIntake(audience: 'patient'),
          }),
          data: <String, dynamic>{
            'audience': 'patient',
          },
        );

        final updated = await client.setAudience(
          'intake_abc',
          audience: 'patient',
        );

        expect(updated.audience, 'patient');
      },
    );

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/audience',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleIntake(audience: 'family_member'),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.setAudience('intake_abc', audience: 'family_member');

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.initiateHandoff', () {
    test(
      'POSTs /v1/intake/<id>/handoff and returns IntakeHandoff with NO '
      'materialised intake',
      () async {
        adapter.onPost(
          '/v1/intake/intake_abc/handoff',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleHandoff(),
          }),
          data: <String, dynamic>{
            'target_subproject_domain': 'ibd.codifyhq.com',
          },
        );

        final handoff = await client.initiateHandoff(
          'intake_abc',
          targetSubprojectDomain: 'ibd.codifyhq.com',
        );

        expect(handoff.token, 'hndf_xyz');
        expect(handoff.targetSubprojectDomain, 'ibd.codifyhq.com');
        expect(handoff.intake, isNull);
      },
    );

    test('forwards metadata in body when provided', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/handoff',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleHandoff(),
        }),
        data: <String, dynamic>{
          'target_subproject_domain': 'ibd.codifyhq.com',
          'metadata': <String, dynamic>{'reason': 'gi_referral'},
        },
      );

      await client.initiateHandoff(
        'intake_abc',
        targetSubprojectDomain: 'ibd.codifyhq.com',
        metadata: const <String, dynamic>{'reason': 'gi_referral'},
      );
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/v1/intake/intake_abc/handoff',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleHandoff(),
        }),
        data: Matchers.any,
      );

      String? capturedKey;
      base.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedKey = options.headers['Idempotency-Key'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.initiateHandoff(
        'intake_abc',
        targetSubprojectDomain: 'ibd.codifyhq.com',
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });
  });

  group('IntakeClient.status', () {
    test('GETs /v1/intake/<id>/status and returns IntakeStatus', () async {
      adapter.onGet(
        '/v1/intake/intake_abc/status',
        (req) => req.reply(200, <String, dynamic>{
          'data': <String, dynamic>{
            'intake_id': 'intake_abc',
            'status': 'voice_pending',
            'updated_at': '2026-05-15T08:00:00Z',
            'ready_for_handoff': false,
          },
        }),
      );

      final status = await client.status('intake_abc');
      expect(status.intakeId, 'intake_abc');
      expect(status.status, 'voice_pending');
      expect(status.readyForHandoff, isFalse);
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/v1/intake/nope/status',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
      );

      expect(
        () => client.status('nope'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
