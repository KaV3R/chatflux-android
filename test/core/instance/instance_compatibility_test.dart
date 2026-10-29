import 'package:fluxer_app/core/instance/instance_compatibility.dart';
import 'package:fluxer_app/core/instance/instance_discovery_service.dart';
import 'package:test/test.dart';

void main() {
  group('InstanceCompatibility', () {
    test('rejects unknown codename in payload', () {
      expect(
        () => InstanceCompatibility.validateDiscoveryPayload(<String, dynamic>{
          'codename': 'future-gen',
        }),
        throwsA(
          predicate<InstanceDiscoveryException>(
            (InstanceDiscoveryException error) =>
                error.reason ==
                InstanceDiscoveryFailureReason.requiresNewerClient,
          ),
        ),
      );
    });

    test('accepts tungsten codename in payload', () {
      expect(
        () => InstanceCompatibility.validateDiscoveryPayload(<String, dynamic>{
          'codename': InstanceCompatibility.currentInstanceCodename,
        }),
        returnsNormally,
      );
    });
  });
}
