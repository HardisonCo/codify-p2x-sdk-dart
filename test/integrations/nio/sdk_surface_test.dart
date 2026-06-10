// SDK surface contract for the NutriScan (NIO) Flutter app.
//
// NIO is the reference consumer — these assertions lock in everything NIO
// currently uses. If any export goes missing, this test won't compile.

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
  test('NIO surface — Firebase swap, KPI, orders, assessments, integrations',
      () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'nutriscan.codify.ai',
      ),
    );

    // Auth
    AuthClient(p2x);
    FirebaseSwapClient(p2x); // primary: Firebase ID token → Sanctum

    // Core daily-flow modules NIO drives
    AssessmentsClient(p2x); // food scans
    KpiClient(p2x); // calories, water, weight, steps
    OrderClient(p2x); // subscription state
    PaymentClient(p2x);
    NotificationClient(p2x);

    // NIO-specific
    NioIntegrationsClient(p2x); // coin balance / spend / grant
    SubprojectsClient(p2x);
  });

  test('NIO can use the new wizard / utils surfaces', () {
    final p2x = P2xClient(
      config: const P2xClientConfig(baseUrl: 'https://api.project20x.com/api'),
    );
    WizardClient(p2x);
    // ignore: unused_local_variable
    const _ = RetryPolicy();
  });
}
