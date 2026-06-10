// SDK surface contract for the PHM Marketplace Flutter apps (patient +
// doctor/lab/store).
//
// PHM has **no Firebase Auth** — apps sign in with email/password directly
// against P2X via PasswordSwapClient. This test gates that primary entry
// point + everything PHM consumes.

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
  test('PHM patient surface — password-swap, orders, schedule, payment', () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'phm.ai',
      ),
    );

    // Primary auth path — PHM doesn't use Firebase
    AuthClient(p2x);
    PasswordSwapClient(p2x);

    // Marketplace flows
    ItemsClient(p2x); // listings + collections
    OrderClient(p2x); // cart + checkout
    PaymentClient(p2x); // Stripe
    ScheduleClient(p2x); // appointments
    ServicesClient(p2x); // service lookup
    ChatClient(p2x);
    NotificationClient(p2x);
  });

  test('PHM doctor/lab/store surface adds intake + assessments + verification',
      () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'phm.ai',
      ),
    );
    PasswordSwapClient(p2x);
    IntakeClient(p2x); // patient intake handoff
    ApplicationClient(p2x); // license + onboarding apps
    AssessmentsClient(p2x);
    VerificationClient(p2x); // license uploads
    FollowUpsClient(p2x);
    KpiClient(p2x); // patient-reported outcomes
  });
}
