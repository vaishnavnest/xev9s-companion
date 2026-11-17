import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('apiBaseUrl default is non-empty', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
    });

    test('apiBaseUrl does not end with a slash', () {
      expect(AppConfig.apiBaseUrl.endsWith('/'), isFalse);
    });

    test('wsBaseUrl default is non-empty', () {
      expect(AppConfig.wsBaseUrl, isNotEmpty);
    });

    test('wsBaseUrl starts with ws:// or wss://', () {
      expect(
        AppConfig.wsBaseUrl.startsWith('ws://') ||
            AppConfig.wsBaseUrl.startsWith('wss://'),
        isTrue,
      );
    });
  });
}
