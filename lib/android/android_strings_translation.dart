import 'dart:developer' as developer;
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/app_paths.dart';
import 'package:translator_dart/locale_mapping.dart';
import 'package:translator_dart/translator.dart';

const _kAndroidStringsLogName = 'translator_dart.android_strings';

class AndroidStringsTranslation {
  final String appDirectory;
  final bool force;
  final TranslationClient? client;

  AndroidStringsTranslation({
    required this.appDirectory,
    this.force = false,
    this.client,
  });

  Future<void> run() async {
    final resDir = joinAppPath(appDirectory, kRelativeAndroidResDir);
    final sourceFile = File('$resDir/values/strings.xml');
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Missing source strings.xml file for app "$appDirectory"',
        sourceFile.path,
      );
    }

    final sourceEntries = parseAndroidStrings(await sourceFile.readAsString());
    if (sourceEntries.isEmpty) {
      developer.log(
        'No Android string resources found in ${sourceFile.path}.',
        name: _kAndroidStringsLogName,
      );
      return;
    }

    final translator = AndroidStringTranslator(client: client);
    developer.log(
      'Translating Android native strings to ${kFlutterLocales.length - 1} languages...',
      name: _kAndroidStringsLogName,
    );
    for (final locale in flutterTranslationLocales()) {
      final language = localeToBcp47(locale);
      developer.log('Started: $language', name: _kAndroidStringsLogName);

      final dir = Directory(
        '$resDir/${flutterLocaleToAndroidValuesDir(locale)}',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final targetFile = File('${dir.path}/strings.xml');
      final existingEntries = await targetFile.exists()
          ? parseAndroidStrings(await targetFile.readAsString())
          : <AndroidStringEntry>[];
      final existingValues = {
        for (final entry in existingEntries) entry.name: entry.value,
      };

      final translatedEntries = <AndroidStringEntry>[];
      for (final entry in sourceEntries) {
        if (!entry.isTranslatable) {
          translatedEntries.add(entry);
          continue;
        }

        final existingValue = existingValues[entry.name];
        if (!force &&
            existingValue != null &&
            existingValue.trim().isNotEmpty) {
          translatedEntries.add(entry.copyWith(value: existingValue));
          continue;
        }

        if (entry.value.trim().isEmpty) {
          translatedEntries.add(entry);
          continue;
        }

        developer.log(
          '  Translating ($language): ${entry.name}',
          name: _kAndroidStringsLogName,
        );
        translatedEntries.add(
          entry.copyWith(
            value: await translator.translateText(entry.value, language),
          ),
        );
      }

      await targetFile.writeAsString(
        formatAndroidStrings(translatedEntries),
        encoding: utf8,
      );
      developer.log('Finished: $language', name: _kAndroidStringsLogName);
    }

    developer.log(
      'Done! Translated to ${kFlutterLocales.length - 1} languages.',
      name: _kAndroidStringsLogName,
    );
  }
}

List<AndroidStringEntry> parseAndroidStrings(String content) {
  final pattern = RegExp(r'<string\b([^>]*)>(.*?)</string>', dotAll: true);
  final entries = <AndroidStringEntry>[];

  for (final match in pattern.allMatches(content)) {
    final attributes = _parseXmlAttributes(match.group(1)!);
    final name = attributes.remove('name');
    if (name == null) {
      continue;
    }

    entries.add(
      AndroidStringEntry(
        name: name,
        value: _decodeXmlText(match.group(2)!),
        attributes: attributes,
      ),
    );
  }

  return entries;
}

String formatAndroidStrings(List<AndroidStringEntry> entries) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<resources>');

  for (final entry in entries) {
    final attrBuffer = StringBuffer()
      ..write(' name="${_escapeXmlAttribute(entry.name)}"');
    for (final attribute in entry.attributes.entries) {
      attrBuffer.write(
        ' ${attribute.key}="${_escapeXmlAttribute(attribute.value)}"',
      );
    }

    buffer.writeln(
      '    <string$attrBuffer>${_escapeXmlText(entry.value)}</string>',
    );
  }

  buffer.writeln('</resources>');
  return buffer.toString();
}

Map<String, String> _parseXmlAttributes(String rawAttributes) {
  final attributes = <String, String>{};
  final pattern = RegExp(r'([A-Za-z_:][A-Za-z0-9_.:-]*)\s*=\s*"([^"]*)"');

  for (final match in pattern.allMatches(rawAttributes)) {
    attributes[match.group(1)!] = _decodeXmlText(match.group(2)!);
  }

  return attributes;
}

String _decodeXmlText(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

String _escapeXmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeXmlAttribute(String value) {
  return _escapeXmlText(value).replaceAll('"', '&quot;');
}

class AndroidStringEntry {
  final String name;
  final String value;
  final LinkedHashMap<String, String> attributes;

  AndroidStringEntry({
    required this.name,
    required this.value,
    Map<String, String>? attributes,
  }) : attributes = LinkedHashMap<String, String>.of(attributes ?? const {});

  bool get isTranslatable => attributes['translatable'] != 'false';

  AndroidStringEntry copyWith({String? value}) {
    return AndroidStringEntry(
      name: name,
      value: value ?? this.value,
      attributes: attributes,
    );
  }
}

/// Translates Android native string resources shown outside Flutter widgets.
class AndroidStringTranslator extends Translator {
  AndroidStringTranslator({super.client});

  @override
  String prompt(String text, String targetLanguage) {
    return 'Translate the following Android string resource value to the '
        'language represented by "$targetLanguage". This text is shown in '
        'Android system UI or native app chrome. Preserve placeholders such '
        'as %1\$s, %d, and \\n exactly as written, and preserve product names '
        'exactly as written. Return only the translated text without quotes.'
        '\n\nText:\n$text';
  }
}
