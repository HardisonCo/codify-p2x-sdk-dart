// SDK surface contract for the Run Tracker (MOB) Flutter app.
//
// MOB is currently a local-only app (Floor ORM, no backend). When MOB grows
// a backend the relevant surface is here — Sanctum bearer minted via
// device-bound guest registration, activity logging, KPI sync. The test
// validates the SDK is *ready* even though MOB hasn't adopted yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
  test(
      'MOB surface (when it goes online) — guest auth, activity, KPI',
      () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'runtracker.codify.ai',
      ),
    );

    // Anonymous-first device auth
    GuestRegisterClient(p2x);

    // Local-then-sync flows
    ActivityClient(p2x); // runs + locations
    KpiClient(p2x); // water, weight, steps
    NotificationClient(p2x);
  });
}
