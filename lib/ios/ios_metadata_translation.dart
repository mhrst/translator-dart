import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/app_paths.dart';
import 'package:translator_dart/locale_mapping.dart';
import 'package:translator_dart/translator.dart';

const kIosMetadataSourceLocale = 'en-US';
const kIosTranslatableMetadataFiles = [
  'name.txt',
  'subtitle.txt',
  'description.txt',
  'keywords.txt',
  'promotional_text.txt',
  'release_notes.txt',
];
const kIosCopiedMetadataFiles = [
  'marketing_url.txt',
  'privacy_url.txt',
  'support_url.txt',
  'apple_tv_privacy_policy.txt',
];
const _kIosMetadataLogName = 'translator_dart.ios_metadata';

class IosMetadataTranslation {
  final String appDirectory;
  final String? filename;
  final bool force;
  final TranslationClient? client;

  IosMetadataTranslation({
    required this.appDirectory,
    this.filename,
    this.force = false,
    this.client,
  });

  Future<void> run() async {
    final translatableFiles = filename == null
        ? kIosTranslatableMetadataFiles
        : [filename!];
    final metadataDir = joinAppPath(appDirectory, kRelativeIosMetadataDir);
    final sourceDir = Directory('$metadataDir/$kIosMetadataSourceLocale');
    if (!await sourceDir.exists()) {
      throw FileSystemException(
        'Missing source metadata directory for app "$appDirectory"',
        sourceDir.path,
      );
    }

    final filesToTranslate = await _existingRelativePaths(
      sourceDir.path,
      translatableFiles,
    );
    final filesToCopy = await _existingRelativePaths(
      sourceDir.path,
      kIosCopiedMetadataFiles,
    );

    if (filesToTranslate.isEmpty && filesToCopy.isEmpty) {
      developer.log(
        'No App Store metadata files found in ${sourceDir.path}.',
        name: _kIosMetadataLogName,
      );
      return;
    }

    developer.log(
      'Translating App Store metadata in $metadataDir',
      name: _kIosMetadataLogName,
    );
    for (final language in kAppStoreMetadataLocales.where(
      (locale) => locale != kIosMetadataSourceLocale,
    )) {
      final localeDir = Directory('$metadataDir/$language');
      if (!await localeDir.exists()) {
        await localeDir.create(recursive: true);
      }

      developer.log('Started: $language', name: _kIosMetadataLogName);
      for (final relativePath in filesToTranslate) {
        await _translateMetadataFile(
          sourceDir.path,
          localeDir.path,
          relativePath,
          language,
          force,
          client,
        );
      }

      for (final relativePath in filesToCopy) {
        await _copyMetadataFile(sourceDir.path, localeDir.path, relativePath);
      }

      developer.log('Finished: $language', name: _kIosMetadataLogName);
    }
  }
}

Future<List<String>> _existingRelativePaths(
  String sourceDir,
  List<String> relativePaths,
) async {
  final files = <String>[];
  for (final relativePath in relativePaths) {
    final file = File('$sourceDir/$relativePath');
    if (await file.exists()) {
      files.add(relativePath);
    }
  }
  return files;
}

Future<void> _translateMetadataFile(
  String sourceDir,
  String localeDir,
  String relativePath,
  String language,
  bool force,
  TranslationClient? client,
) async {
  final sourceFile = File('$sourceDir/$relativePath');
  final targetFile = File('$localeDir/$relativePath');
  final sourceText = await sourceFile.readAsString();
  await targetFile.parent.create(recursive: true);

  if (sourceText.trim().isEmpty) {
    await targetFile.writeAsString(sourceText, encoding: utf8);
    return;
  }

  if (!force && await targetFile.exists()) {
    final existingText = await targetFile.readAsString();
    if (existingText.trim().isNotEmpty) {
      return;
    }
  }

  final translator = IosMetadataTranslator(relativePath, client: client);
  final translatedValue = await translator.translateText(sourceText, language);
  await targetFile.writeAsString(translatedValue, encoding: utf8);
}

Future<void> _copyMetadataFile(
  String sourceDir,
  String localeDir,
  String relativePath,
) async {
  final sourceFile = File('$sourceDir/$relativePath');
  final targetFile = File('$localeDir/$relativePath');
  await targetFile.parent.create(recursive: true);
  await targetFile.writeAsString(
    await sourceFile.readAsString(),
    encoding: utf8,
  );
}

/// Translates App Store metadata files with field-specific prompt guidance.
class IosMetadataTranslator extends Translator {
  final String relativePath;

  IosMetadataTranslator(this.relativePath, {super.client});

  @override
  String prompt(String text, String targetLanguage) {
    final langCode = localeToBcp47(targetLanguage);
    return 'Translate the following English App Store listing metadata to '
        'the language represented by "$langCode". '
        'Preserve product names and brand names exactly as written, keep '
        'URLs unchanged, and preserve line breaks and list formatting. '
        '${_fieldInstructions(relativePath)} '
        'Return only the translated text without quotes.\n\n'
        'Field: $relativePath\n'
        'Text:\n$text';
  }

  String _fieldInstructions(String relativePath) {
    switch (relativePath) {
      case 'name.txt':
        return 'Keep the result concise enough for an App Store app name.';
      case 'subtitle.txt':
        return 'Keep the result concise enough for an App Store subtitle.';
      case 'keywords.txt':
        return 'Return only a comma-separated keyword list.';
      case 'release_notes.txt':
        return 'Keep the tone appropriate for release notes.';
      default:
        return '';
    }
  }
}
