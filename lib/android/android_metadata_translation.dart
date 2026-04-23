import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/app_paths.dart';
import 'package:translator_dart/locale_mapping.dart';
import 'package:translator_dart/translator.dart';

const kAndroidMetadataSourceLocale = 'en-US';
const kAndroidTranslatableMetadataFiles = [
  'title.txt',
  'short_description.txt',
  'full_description.txt',
];
const kAndroidCopiedMetadataFiles = ['video.txt'];
const _kAndroidMetadataLogName = 'translator_dart.android_metadata';

class AndroidMetadataTranslation {
  final String appDirectory;
  final bool force;
  final TranslationClient? client;

  AndroidMetadataTranslation({
    required this.appDirectory,
    this.force = false,
    this.client,
  });

  Future<void> run() async {
    final metadataDir = joinAppPath(appDirectory, kRelativeAndroidMetadataDir);
    final sourceDir = Directory('$metadataDir/$kAndroidMetadataSourceLocale');
    if (!await sourceDir.exists()) {
      throw FileSystemException(
        'Missing source metadata directory for app "$appDirectory"',
        sourceDir.path,
      );
    }

    final filesToTranslate = [
      ...await _existingRelativePaths(
        sourceDir.path,
        kAndroidTranslatableMetadataFiles,
      ),
      ...await _relativeTextFiles(
        '$metadataDir/$kAndroidMetadataSourceLocale/changelogs',
      ),
    ];
    final filesToCopy = await _existingRelativePaths(
      sourceDir.path,
      kAndroidCopiedMetadataFiles,
    );

    if (filesToTranslate.isEmpty && filesToCopy.isEmpty) {
      developer.log(
        'No Google Play metadata files found in ${sourceDir.path}.',
        name: _kAndroidMetadataLogName,
      );
      return;
    }

    developer.log(
      'Translating Google Play metadata in $metadataDir',
      name: _kAndroidMetadataLogName,
    );
    for (final language in kPlayStoreMetadataLocales.where(
      (locale) => locale != kAndroidMetadataSourceLocale,
    )) {
      final localeDir = Directory('$metadataDir/$language');
      if (!await localeDir.exists()) {
        await localeDir.create(recursive: true);
      }

      developer.log('Started: $language', name: _kAndroidMetadataLogName);
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

      developer.log('Finished: $language', name: _kAndroidMetadataLogName);
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

Future<List<String>> _relativeTextFiles(String sourceDir) async {
  final dir = Directory(sourceDir);
  if (!await dir.exists()) {
    return [];
  }

  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'))
          .map(
            (file) =>
                file.path.substring(sourceDir.length + 1).replaceAll('\\', '/'),
          )
          .toList()
        ..sort();

  return files.map((path) => 'changelogs/$path').toList();
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

  final translator = AndroidMetadataTranslator(relativePath, client: client);
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

/// Translates Google Play metadata files with field-specific prompt guidance.
class AndroidMetadataTranslator extends Translator {
  final String relativePath;

  AndroidMetadataTranslator(this.relativePath, {super.client});

  @override
  String prompt(String text, String targetLanguage) {
    return 'Translate the following English Google Play metadata to the '
        'language represented by "$targetLanguage". Preserve product names '
        'exactly as written, keep URLs unchanged, and preserve line breaks, '
        'bullets, and paragraph formatting. ${_fieldInstructions(relativePath)} '
        'Return only the translated text without quotes.\n\n'
        'Field: $relativePath\n'
        'Text:\n$text';
  }

  String _fieldInstructions(String relativePath) {
    if (relativePath == 'title.txt') {
      return 'Keep the result concise enough for a Google Play app title.';
    }
    if (relativePath == 'short_description.txt') {
      return 'Keep the result concise enough for a Google Play short description.';
    }
    if (relativePath.startsWith('changelogs/')) {
      return 'Keep the tone appropriate for release notes.';
    }
    return '';
  }
}
