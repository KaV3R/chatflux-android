import 'package:fluxer_app/core/instance/instance_compatibility_messages.dart';
import 'package:fluxer_app/core/instance/instance_endpoint_normalizer.dart';
import 'package:fluxer_app/features/auth/providers/instance_selector_provider.dart';
import 'package:fluxer_app/l10n/generated/fluxer_localizations.dart';

String instanceDiscoveryErrorText(
  InstanceSelectorState state,
  FluxerLocalizations l10n,
) {
  final String domain = const InstanceEndpointNormalizer().describeApiEndpoint(
    state.instanceUrl,
  );
  return instanceDiscoveryFailureMessage(
    reason: state.discoveryFailureReason,
    errorMessage: state.errorMessage,
    domain: domain,
    l10n: l10n,
  );
}
