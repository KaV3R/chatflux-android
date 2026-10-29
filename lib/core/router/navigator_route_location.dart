String? persistedNavigatorRouteLocation({String? name, Object? arguments}) {
  if (arguments is String && arguments.startsWith('/')) {
    return arguments;
  }
  if (name != null && name.startsWith('/')) {
    return name;
  }
  return null;
}
