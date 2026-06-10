import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/realtime/channels.dart';

void main() {
  test('user / guest / subprojectAgents / pipelineState builders', () {
    expect(ChannelNames.user(42), 'private-user-42');
    expect(ChannelNames.guest('s-abc'), 'private-guest-s-abc');
    expect(ChannelNames.subprojectAgents(7), 'private-subproject-7-agents');
    expect(ChannelNames.codifyOntology, 'private-codify-ontology');
    expect(
      ChannelNames.pipelineState('sess-1'),
      'private-pipeline-state-sess-1',
    );
  });
}
