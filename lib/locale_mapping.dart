const kFlutterLocales = [
  'en',
  'af',
  'am',
  'ar',
  'bg',
  'ca',
  'zh',
  'zh_HK',
  'zh_CN',
  'zh_TW',
  'hr',
  'cs',
  'da',
  'nl',
  'et',
  'fi',
  'fr',
  'fr_CA',
  'fr_FR',
  'de',
  'el',
  'he',
  'hi',
  'hu',
  'id',
  'it',
  'ja',
  'ko',
  'lv',
  'lt',
  'ms',
  'nb',
  'fa',
  'pl',
  'pt',
  'pt_BR',
  'pt_PT',
  'ro',
  'ru',
  'sr',
  'sk',
  'sl',
  'es',
  'sw',
  'sv',
  'th',
  'tr',
  'uk',
  'vi',
  'zu',
];

const kAppStoreMetadataLocales = [
  'ar-SA',
  'ca',
  'cs',
  'da',
  'de-DE',
  'el',
  'en-AU',
  'en-CA',
  'en-GB',
  'en-US',
  'es-ES',
  'es-MX',
  'fi',
  'fr-CA',
  'fr-FR',
  'he',
  'hi',
  'hr',
  'hu',
  'id',
  'it',
  'ja',
  'ko',
  'ms',
  'nl-NL',
  'no',
  'pl',
  'pt-BR',
  'pt-PT',
  'ro',
  'ru',
  'sk',
  'sv',
  'th',
  'tr',
  'uk',
  'vi',
  'zh-Hans',
  'zh-Hant',
];

const kPlayStoreMetadataLocales = [
  'en-US',
  'af',
  'am',
  'ar',
  'bg',
  'ca',
  'cs-CZ',
  'da-DK',
  'de-DE',
  'el-GR',
  'es-ES',
  'et',
  'fa',
  'fi-FI',
  'fr-CA',
  'fr-FR',
  'he-IL',
  'hi-IN',
  'hr',
  'hu-HU',
  'id',
  'it-IT',
  'ja-JP',
  'ko-KR',
  'lt',
  'lv',
  'ms',
  'no-NO',
  'nl-NL',
  'pl-PL',
  'pt-BR',
  'pt-PT',
  'ro',
  'ru-RU',
  'sk',
  'sl',
  'sr',
  'sv-SE',
  'sw',
  'th',
  'tr-TR',
  'uk',
  'vi',
  'zh-CN',
  'zh-HK',
  'zh-TW',
  'zu',
];

Iterable<String> flutterTranslationLocales() sync* {
  for (final locale in kFlutterLocales) {
    if (locale != 'en') {
      yield locale;
    }
  }
}

String localeToBcp47(String locale) => locale.replaceAll('_', '-');

String flutterLocaleToAndroidValuesDir(String locale) {
  if (locale == 'en') {
    return 'values';
  }

  final parts = locale.split('_');
  if (parts.length == 1) {
    return 'values-${parts[0]}';
  }

  return 'values-${parts[0]}-r${parts[1]}';
}

String flutterLocaleToIosLproj(String locale) {
  switch (locale) {
    case 'zh_CN':
      return 'zh-Hans.lproj';
    case 'zh_HK':
      return 'zh-HK.lproj';
    case 'zh_TW':
      return 'zh-TW.lproj';
    default:
      return '${localeToBcp47(locale)}.lproj';
  }
}
