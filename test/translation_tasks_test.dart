import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:translator_dart/translator_dart.dart';

void main() {
  group('Task execution', () {
    test('runs ARB translation as an importable task', () async {
      final tempDir = await Directory.systemTemp.createTemp('translator_dart_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final l10nDir = Directory(joinAppPath(tempDir.path, kRelativeL10nDir));
      await l10nDir.create(recursive: true);

      final sourceFile = File('${l10nDir.path}/app_en.arb');
      await sourceFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          '@@locale': 'en',
          'title': 'Hello',
          '@title': {'description': 'Greeting'},
        }),
      );

      final task = ArbTranslation(
        appDirectory: tempDir.path,
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async => 'translated',
        ),
      );

      await task.run();

      final frFile = File('${l10nDir.path}/app_fr.arb');
      final frJson =
          jsonDecode(await frFile.readAsString()) as Map<String, dynamic>;
      expect(frJson['@@locale'], 'fr');
      expect(frJson['title'], 'translated');
      expect(frJson['@title'], {'description': 'Greeting'});
    });

    test('filters iOS metadata translation by filename', () async {
      final tempDir = await Directory.systemTemp.createTemp('translator_dart_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourceDir = Directory(
        '${joinAppPath(tempDir.path, kRelativeIosMetadataDir)}/$kIosMetadataSourceLocale',
      );
      await sourceDir.create(recursive: true);
      await File('${sourceDir.path}/name.txt').writeAsString('Inkpad');
      await File('${sourceDir.path}/description.txt').writeAsString('Draw');

      final task = IosMetadataTranslation(
        appDirectory: tempDir.path,
        filename: 'name.txt',
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async => 'translated',
        ),
      );

      await task.run();

      final frNameFile = File(
        '${joinAppPath(tempDir.path, kRelativeIosMetadataDir)}/fr/name.txt',
      );
      final frDescriptionFile = File(
        '${joinAppPath(tempDir.path, kRelativeIosMetadataDir)}/fr/description.txt',
      );

      expect(await frNameFile.exists(), isTrue);
      expect(await frNameFile.readAsString(), 'translated');
      expect(await frDescriptionFile.exists(), isFalse);
    });
  });
}

class _FakeTranslationClient implements TranslationClient {
  final Future<String> Function(String prompt) _translatePrompt;

  _FakeTranslationClient({
    required Future<String> Function(String prompt) translatePrompt,
  }) : _translatePrompt = translatePrompt;

  @override
  TranslationProvider get provider => TranslationProvider.openai;

  @override
  String get model => 'gpt-5.4';

  @override
  Future<String> translatePrompt(String prompt) {
    return _translatePrompt(prompt);
  }
}
