abstract final class InstanceConstants {
  static const int apiCodeVersion = 1;
  // ChatFlux: our own instance is the default.
  static const String defaultApiBaseUrl = 'https://chat.catflux.hu/api/v1';
  static const String defaultGatewayUrl = 'wss://chat.catflux.hu/gateway';
  static const String defaultInstanceInputUrl = 'chat.catflux.hu';
  static const String canaryApiBaseUrl = 'https://chat.catflux.hu/api/v1';
  static const String canaryInstanceInputUrl = 'chat.catflux.hu';
  static const String defaultMarketingBaseUrl = 'https://chat.catflux.hu';
  static const String defaultProductName = 'ChatFlux';
  static const String defaultPremiumProductName = 'Plutonium';
  static const int maxRecentInstances = 5;

  static const Set<String> officialInstanceHosts = <String>{
    'chat.catflux.hu',
  };
}
