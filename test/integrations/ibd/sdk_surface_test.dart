// SDK surface contract for the Crohnie AI / IBD Healthcare Flutter apps
// (patient + clinician).
//
// IBD uses Firebase Auth → Sanctum swap (same as NIO), plus the chat /
// schedule / verification / follow-ups modules for doctor↔patient flows.

import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/ycaas_flutter_sdk.dart';

void main() {
  test('IBD patient surface — chat, schedule, follow-ups, assessments', () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'crohnie.ai',
      ),
    );

    AuthClient(p2x);
    FirebaseSwapClient(p2x);

    // Doctor↔patient
    ChatClient(p2x);
    ScheduleClient(p2x);
    ServicesClient(p2x);
    FollowUpsClient(p2x);

    // Clinical intake
    ApplicationClient(p2x);
    IntakeClient(p2x);
    AssessmentsClient(p2x);
    VerificationClient(p2x);

    // Payments + notifications
    OrderClient(p2x);
    PaymentClient(p2x);
    NotificationClient(p2x);
  });

  test('IBD clinician surface adds agents + referrals + reports', () {
    final p2x = P2xClient(
      config: P2xClientConfig(
        baseUrl: 'https://api.project20x.com/api',
        getDomain: () => 'crohnie.ai',
      ),
    );
    AgentsClient(p2x); // clinician-side AI assist
    ReferralClient(p2x); // outbound referrals
    ReportClient(p2x); // clinical reports
    DealsClient(p2x); // care-plan deals
    WizardClient(p2x); // codifying new care protocols
  });
}
