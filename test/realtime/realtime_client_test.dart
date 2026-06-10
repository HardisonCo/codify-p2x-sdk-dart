import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/realtime/realtime_client.dart';

void main() {
  group('NoopRealtimeClient', () {
    test('connect / disconnect / unsubscribe complete without throwing',
        () async {
      const c = NoopRealtimeClient();
      await c.connect();
      await c.disconnect();
      await c.unsubscribe('private-user-1');
    });

    test('subscribe returns an empty stream', () async {
      const c = NoopRealtimeClient();
      final stream = c.subscribe('private-user-1');
      expect(await stream.toList(), isEmpty);
    });
  });
}
