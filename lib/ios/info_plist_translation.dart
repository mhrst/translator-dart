import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/app_paths.dart';
import 'package:translator_dart/locale_mapping.dart';
import 'package:translator_dart/translator.dart';

const kInfoPlistTranslatableKeys = [
  'CFBundleDisplayName',
  'NSCameraUsageDescription',
  'NSLocationAlwaysAndWhenInUseUsageDescription',
  'NSLocationWhenInUseUsageDescription',
  'NSMicrophoneUsageDescription',
  'NSPhotoLibraryUsageDescription',
];
const _kInfoPlistLogName = 'translator_dart.info_plist';

class InfoPlistTranslation {
  final String appDirectory;
  final bool force;
  final TranslationClient? client;

  InfoPlistTranslation({
    required this.appDirectory,
    this.force = false,
    this.client,
  });

  Future<void> run() async {
    final outputRoot = joinAppPath(appDirectory, kRelativeIosRunnerDir);
    final sourcePlist = File('$outputRoot/Info.plist');
    if (!sourcePlist.existsSync()) {
      throw FileSystemException(
        'Missing Info.plist file for app "$appDirectory"',
        sourcePlist.path,
      );
    }

    final sourceStrings = await loadSourceInfoPlistStrings(sourcePlist);
    if (sourceStrings.isEmpty) {
      developer.log(
        'No translatable Info.plist strings found in ${sourcePlist.path}.',
        name: _kInfoPlistLogName,
      );
      return;
    }

    final translator = InfoPlistTranslator(client: client);
    developer.log(
      'Translating Info.plist strings to ${kFlutterLocales.length - 1} languages...',
      name: _kInfoPlistLogName,
    );

    for (final locale in flutterTranslationLocales()) {
      final language = localeToBcp47(locale);
      developer.log('Started: $language', name: _kInfoPlistLogName);

      final dir = Directory('$outputRoot/${flutterLocaleToIosLproj(locale)}');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final langFile = File('${dir.path}/InfoPlist.strings');
      final existingTranslations = await langFile.exists()
          ? parseInfoPlistStrings(await langFile.readAsString())
          : <String, String>{};
      final translations = <String, String>{};

      for (final entry in sourceStrings.entries) {
        final existingValue = existingTranslations[entry.key];
        if (!force &&
            existingValue != null &&
            existingValue.trim().isNotEmpty) {
          translations[entry.key] = existingValue;
          continue;
        }

        if (entry.value.trim().isEmpty) {
          translations[entry.key] = entry.value;
          continue;
        }

        developer.log(
          '  Translating ($language): ${entry.key}',
          name: _kInfoPlistLogName,
        );
        translations[entry.key] = await translator.translateText(
          entry.value,
          language,
        );
      }

      await langFile.writeAsString(
        formatInfoPlistStrings(translations),
        encoding: utf8,
      );
      developer.log('Finished: $language', name: _kInfoPlistLogName);
    }

    developer.log(
      'Done! Translated to ${kFlutterLocales.length - 1} languages.',
      name: _kInfoPlistLogName,
    );
  }
}

Future<Map<String, String>> loadSourceInfoPlistStrings(File sourcePlist) async {
  final content = await sourcePlist.readAsString();
  final values = <String, String>{};
  for (final key in kInfoPlistTranslatableKeys) {
    final value = extractInfoPlistValue(content, key);
    if (value != null) {
      values[key] = value;
    }
  }
  return values;
}

String? extractInfoPlistValue(String content, String key) {
  final pattern = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>(.*?)</string>',
    dotAll: true,
  );
  final match = pattern.firstMatch(content);
  if (match == null) {
    return null;
  }

  return _decodeXmlText(match.group(1)!);
}

/// Parses an InfoPlist.strings file content into a map of key-value pairs
/// Format: "key" = "value";
Map<String, String> parseInfoPlistStrings(String content) {
  final Map<String, String> result = {};
  final RegExp pattern = RegExp(
    r'"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
    dotAll: true,
  );

  for (final match in pattern.allMatches(content)) {
    final key = _decodeEscapedPlistString(match.group(1)!);
    final value = _decodeEscapedPlistString(match.group(2)!);
    result[key] = value;
  }

  return result;
}

/// Formats a map of translations into InfoPlist.strings format
/// Format: "key" = "value";
String formatInfoPlistStrings(Map<String, String> entries) {
  final buffer = StringBuffer();

  for (final entry in entries.entries) {
    final escapedKey = _encodeEscapedPlistString(entry.key);
    final escapedValue = _encodeEscapedPlistString(entry.value);
    buffer.writeln('"$escapedKey" = "$escapedValue";');
  }

  return buffer.toString();
}

String _decodeEscapedPlistString(String value) {
  return value
      .replaceAll(r'\"', '"')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', '\\');
}

String _encodeEscapedPlistString(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('"', r'\"');
}

String _decodeXmlText(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

/// Translates Info.plist strings that appear in iOS system prompts and chrome.
class InfoPlistTranslator extends Translator {
  InfoPlistTranslator({super.client});

  @override
  String prompt(String text, String targetLanguage) {
    return 'Translate the following iOS Info.plist string to the language '
        'represented by "$targetLanguage". This text is shown in iOS system '
        'UI, including permission prompts and the localized app name. '
        'Preserve product names exactly as written, and keep the wording '
        'natural and concise. Return only the translated text without quotes.'
        '\n\nText:\n$text';
  }
}
