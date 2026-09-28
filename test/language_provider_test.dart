import 'package:flutter_test/flutter_test.dart';
import 'package:qvasave_pro/core/providers/service_providers.dart';

void main() {
  group('resolveAppLanguageCode', () {
    test('keeps supported language codes', () {
      expect(resolveAppLanguageCode('es'), 'es');
      expect(resolveAppLanguageCode('en'), 'en');
    });

    test('uses Spanish for unsupported or missing language codes', () {
      expect(resolveAppLanguageCode('fr'), 'es');
      expect(resolveAppLanguageCode('zh'), 'es');
      expect(resolveAppLanguageCode(null), 'es');
    });
  });
}
