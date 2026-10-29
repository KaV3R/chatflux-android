import 'package:fluxer_app/core/api/fluxer_client_properties.dart';
import 'package:fluxer_app/core/build/app_build_config.dart';
import 'package:fluxer_app/core/build/app_build_environment.dart';

class MeasureVersionMetadata {
  const MeasureVersionMetadata({
    required this.serviceVersion,
    this.buildNumber,
  });

  final String serviceVersion;
  final String? buildNumber;
}

MeasureVersionMetadata? resolveMeasureVersionMetadata({
  required AppBuildEnvironment environment,
  required String? releaseVersion,
  required String? platformBuildNumber,
  int? betaNumber,
  int? canaryNumber,
}) {
  final String? version = normalizeOptionalString(releaseVersion);
  if (version == null) {
    return null;
  }

  switch (environment) {
    case AppBuildEnvironment.stable:
      return MeasureVersionMetadata(serviceVersion: version);
    case AppBuildEnvironment.beta:
      final int? beta = betaNumber ?? AppBuildConfig.betaNumber;
      return MeasureVersionMetadata(
        serviceVersion: version,
        buildNumber: beta?.toString(),
      );
    case AppBuildEnvironment.canary:
      final int? canary = canaryNumber ?? AppBuildConfig.canaryNumber;
      final String? buildNumber = canary == null
          ? normalizeOptionalString(platformBuildNumber)
          : canary.toString();
      return MeasureVersionMetadata(
        serviceVersion: version,
        buildNumber: buildNumber,
      );
  }
}
