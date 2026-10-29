import 'package:fluxer_app/core/router/navigator_route_location.dart';
import 'package:test/test.dart';

void main() {
  group('persistedNavigatorRouteLocation', () {
    test('prefers path arguments over route name', () {
      expect(
        persistedNavigatorRouteLocation(
          name: 'channel',
          arguments: '/channels/1/2',
        ),
        '/channels/1/2',
      );
    });

    test('falls back to path route name', () {
      expect(
        persistedNavigatorRouteLocation(name: '/channels/1/2'),
        '/channels/1/2',
      );
    });

    test('ignores symbolic route names', () {
      expect(persistedNavigatorRouteLocation(name: 'channel'), isNull);
    });
  });
}
