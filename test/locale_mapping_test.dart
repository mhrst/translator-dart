import 'package:flutter_test/flutter_test.dart';
import 'package:translator_dart/locale_mapping.dart';

void main() {
  test('App Store metadata locales use Fastlane-supported directory names', () {
    const unsupportedFastlaneMetadataLocales = {
      'ar',
      'de',
      'es',
      'fr',
      'nl',
      'pt',
      'zh',
    };

    expect(
      kAppStoreMetadataLocales,
      isNot(containsAll(unsupportedFastlaneMetadataLocales)),
    );
    for (final locale in unsupportedFastlaneMetadataLocales) {
      expect(kAppStoreMetadataLocales, isNot(contains(locale)));
    }
  });
}
