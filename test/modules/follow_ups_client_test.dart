// Contract tests for FollowUpsClient.
//
// Mirrors the TS FollowUpsModuleApiClient:
//   GET    /api/follow-ups
//   POST   /api/follow-ups
//   GET    /api/follow-ups/<id>
//   PUT    /api/follow-ups/<id>                    (over wire: POST + ?_method=PUT)
//   POST   /api/follow-ups/<id>/voice/record
//   POST   /api/follow-ups/<id>/voice/finalize

import 'package:codify_p2x_sdk/src/client/exceptions/not_found_exception.dart';
import 'package:codify_p2x_sdk/src/client/exceptions/validation_exception.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client.dart';
import 'package:codify_p2x_sdk/src/client/p2x_client_config.dart';
import 'package:codify_p2x_sdk/src/modules/follow_ups_client.dart';
import 'package:codify_p2x_sdk/src/modules/follow_ups_models.dart';
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
  late FollowUpsClient client;

  Map<String, dynamic> sampleFollowUp({
    int id = 21,
    String status = 'pending',
    String? voiceUrl,
    int? voiceDurationSeconds,
  }) =>
      <String, dynamic>{
        'id': id,
        'patient_id': 99,
        'provider_id': 42,
        'due_at': '2026-05-25T08:00:00Z',
        'status': status,
        if (voiceUrl != null) 'voice_url': voiceUrl,
        if (voiceDurationSeconds != null)
          'voice_duration_seconds': voiceDurationSeconds,
        'created_at': '2026-05-20T08:00:00Z',
        'updated_at': '2026-05-20T08:00:00Z',
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
    client = FollowUpsClient(base);
  });

  group('FollowUpsClient.list', () {
    test('GETs /follow-ups with no query params by default', () async {
      adapter.onGet(
        '/follow-ups',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[
            sampleFollowUp(),
            sampleFollowUp(id: 22, status: 'completed'),
          ],
        }),
      );

      final list = await client.list();

      expect(list, hasLength(2));
      expect(list.first.id, 21);
      expect(list.last.status, 'completed');
    });

    test('GETs /follow-ups filtered by patientId and status', () async {
      adapter.onGet(
        '/follow-ups',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[sampleFollowUp()],
        }),
        queryParameters: <String, dynamic>{
          'patient_id': '99',
          'status': 'pending',
        },
      );

      final list = await client.list(patientId: '99', status: 'pending');
      expect(list, hasLength(1));
    });

    test('returns empty list when server returns no rows', () async {
      adapter.onGet(
        '/follow-ups',
        (req) => req.reply(200, <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        }),
      );

      final list = await client.list();
      expect(list, isEmpty);
    });
  });

  group('FollowUpsClient.create', () {
    test('POSTs /follow-ups with body and returns the saved FollowUp',
        () async {
      adapter.onPost(
        '/follow-ups',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleFollowUp(id: 100),
        }),
        data: Matchers.any,
      );

      final saved = await client.create(
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
      );

      expect(saved, isA<FollowUp>());
      expect(saved.id, 100);
      expect(saved.patientId, 99);
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/follow-ups',
        (req) => req.reply(201, <String, dynamic>{
          'data': sampleFollowUp(id: 101),
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

      await client.create(
        patientId: 99,
        providerId: 42,
        dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/follow-ups',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'patient_id': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.create(
          patientId: 0,
          providerId: 42,
          dueAt: DateTime.parse('2026-05-25T08:00:00Z'),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FollowUpsClient.get', () {
    test('GETs /follow-ups/<id> and returns one FollowUp', () async {
      adapter.onGet(
        '/follow-ups/21',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleFollowUp(),
        }),
      );

      final got = await client.get(21);
      expect(got.id, 21);
      expect(got.status, 'pending');
    });

    test('throws NotFoundException on 404', () async {
      adapter.onGet(
        '/follow-ups/999',
        (req) => req.reply(404, <String, dynamic>{'message': 'Not found.'}),
      );

      expect(
        () => client.get(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('FollowUpsClient.update', () {
    test('PUTs /follow-ups/<id> via POST + ?_method=PUT', () async {
      adapter.onPost(
        '/follow-ups/21',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleFollowUp(status: 'completed'),
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      final updated = await client.update(
        21,
        status: 'completed',
        notes: 'Patient feels much better.',
      );

      expect(updated.status, 'completed');
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/follow-ups/21',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'status': <String>['Invalid status.'],
          },
        }),
        data: Matchers.any,
        queryParameters: <String, dynamic>{'_method': 'PUT'},
      );

      expect(
        () => client.update(21, status: 'bogus'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FollowUpsClient.recordVoice', () {
    test(
      'POSTs /follow-ups/<id>/voice/record with audio_url + '
      'duration_seconds and returns the updated FollowUp',
      () async {
        adapter.onPost(
          '/follow-ups/21/voice/record',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleFollowUp(
              voiceUrl: 'https://cdn.x/voice.m4a',
              voiceDurationSeconds: 42,
            ),
          }),
          data: <String, dynamic>{
            'audio_url': 'https://cdn.x/voice.m4a',
            'duration_seconds': 42,
          },
        );

        final updated = await client.recordVoice(
          21,
          audioUrl: 'https://cdn.x/voice.m4a',
          duration: const Duration(seconds: 42),
        );

        expect(updated.voiceUrl, 'https://cdn.x/voice.m4a');
        expect(updated.voiceDurationSeconds, 42);
      },
    );

    test('serializes duration via inSeconds', () async {
      adapter.onPost(
        '/follow-ups/21/voice/record',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleFollowUp(
            voiceUrl: 'https://cdn.x/v.m4a',
            voiceDurationSeconds: 95,
          ),
        }),
        data: <String, dynamic>{
          'audio_url': 'https://cdn.x/v.m4a',
          'duration_seconds': 95, // 1m 35s
        },
      );

      final updated = await client.recordVoice(
        21,
        audioUrl: 'https://cdn.x/v.m4a',
        duration: const Duration(minutes: 1, seconds: 35),
      );

      expect(updated.voiceDurationSeconds, 95);
    });

    test('auto-attaches a UUID v4 Idempotency-Key on POST', () async {
      adapter.onPost(
        '/follow-ups/21/voice/record',
        (req) => req.reply(200, <String, dynamic>{
          'data': sampleFollowUp(
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

      await client.recordVoice(
        21,
        audioUrl: 'https://cdn.x/voice.m4a',
        duration: const Duration(seconds: 42),
      );

      expect(capturedKey, isNotNull);
      expect(_uuidV4.hasMatch(capturedKey!), isTrue);
    });

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/follow-ups/21/voice/record',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'audio_url': <String>['Required.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.recordVoice(
          21,
          audioUrl: '',
          duration: const Duration(seconds: 1),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('FollowUpsClient.finalizeVoice', () {
    test(
      'POSTs /follow-ups/<id>/voice/finalize and returns the updated '
      'FollowUp',
      () async {
        adapter.onPost(
          '/follow-ups/21/voice/finalize',
          (req) => req.reply(200, <String, dynamic>{
            'data': sampleFollowUp(
              status: 'in_progress',
              voiceUrl: 'https://cdn.x/voice.m4a',
              voiceDurationSeconds: 42,
            ),
          }),
          data: Matchers.any,
        );

        final updated = await client.finalizeVoice(21);

        expect(updated.status, 'in_progress');
        expect(updated.voiceUrl, isNotNull);
      },
    );

    test('throws ValidationException on 422', () async {
      adapter.onPost(
        '/follow-ups/21/voice/finalize',
        (req) => req.reply(422, <String, dynamic>{
          'message': 'The given data was invalid.',
          'errors': <String, dynamic>{
            'voice_url': <String>['No recording present.'],
          },
        }),
        data: Matchers.any,
      );

      expect(
        () => client.finalizeVoice(21),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
