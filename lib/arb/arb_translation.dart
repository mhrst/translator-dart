import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/app_paths.dart';
import 'package:translator_dart/locale_mapping.dart';
import 'package:translator_dart/translator.dart';

const _kArbTranslationLogName = 'translator_dart.arb';

class ArbTranslation {
  final String appDirectory;
  final bool force;
  final TranslationClient? client;

  ArbTranslation({required this.appDirectory, this.force = false, this.client});

  Future<void> run() async {
    final l10nConfiguration = resolveL10nConfiguration(appDirectory);
    final arbFilePath = l10nConfiguration.arbDirectoryPath(appDirectory);
    final translator = ArbTranslator(client: client);

    final sourceFile = File(
      '$arbFilePath/${l10nConfiguration.templateArbFile}',
    );
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Missing source ARB file for app "$appDirectory"',
        sourceFile.path,
      );
    }

    final enContent = await sourceFile.readAsString();
    final Map<String, Object?> enJson = jsonDecode(enContent);

    await Future.wait(
      flutterTranslationLocales().map((language) async {
        developer.log('Started: $language', name: _kArbTranslationLogName);
        final appLangArbFile = File(
          '$arbFilePath/${localizedArbFileName(l10nConfiguration.templateArbFile, language)}',
        );
        Map<String, dynamic> langJson = {};

        if (await appLangArbFile.exists()) {
          final langContent = await appLangArbFile.readAsString();
          langJson = json.decode(langContent);
        }

        final translatedJson = <String, dynamic>{};
        for (final key in enJson.keys) {
          if (key.startsWith('@')) {
            if (key == '@@locale') {
              translatedJson[key] = language.replaceAll('-', '_');
            } else {
              translatedJson[key] = enJson[key];
            }
            continue;
          }

          if (force || !langJson.containsKey(key)) {
            developer.log(
              'Translating ($language): $key',
              name: _kArbTranslationLogName,
            );
            final value = enJson[key] is Map
                ? jsonEncode(enJson[key])
                : enJson[key].toString();

            final translatedValue = await translator.translateText(
              value,
              language,
            );
            translatedJson[key] = translatedValue;
          } else {
            translatedJson[key] = langJson[key];
          }
        }

        await appLangArbFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(translatedJson),
          encoding: utf8,
        );
        developer.log('Finished: $language', name: _kArbTranslationLogName);
      }),
    );
  }
}

String localizedArbFileName(String templateArbFile, String locale) {
  final normalizedLocale = locale.replaceAll('-', '_');
  final extensionStart = templateArbFile.lastIndexOf('.');
  final stem = extensionStart == -1
      ? templateArbFile
      : templateArbFile.substring(0, extensionStart);
  final extension = extensionStart == -1
      ? ''
      : templateArbFile.substring(extensionStart);

  if (stem.endsWith('_en')) {
    return '${stem.substring(0, stem.length - 3)}_$normalizedLocale$extension';
  }
  if (stem.endsWith('-en')) {
    return '${stem.substring(0, stem.length - 3)}_$normalizedLocale$extension';
  }

  return 'app_$normalizedLocale.arb';
}

/// Translates Flutter ARB values while leaving the file traversal unchanged.
class ArbTranslator extends Translator {
  ArbTranslator({super.client});

  @override
  String prompt(String text, String targetLanguage) {
    final langCode = targetLanguage.replaceAll('_', '-');
    return 'Translate the following English text value from an .arb file to the '
        'language represented by the language code "$langCode": "$text". '
        'Return only the translated text and don\'t wrap in quotes.';
  }
}
