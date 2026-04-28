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

    test('uses l10n.yaml for ARB translation paths', () async {
      final tempDir = await Directory.systemTemp.createTemp('translator_dart_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File('${tempDir.path}/l10n.yaml').writeAsString('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
''');

      final l10nDir = Directory(joinAppPath(tempDir.path, 'lib/l10n'));
      await l10nDir.create(recursive: true);
      await File('${l10nDir.path}/app_en.arb').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'@@locale': 'en', 'title': 'Hello'}),
      );

      final task = ArbTranslation(
        appDirectory: tempDir.path,
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async => 'translated',
        ),
      );

      await task.run();

      expect(await File('${l10nDir.path}/app_fr.arb').exists(), isTrue);
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

    test('filters Android metadata translation by relative paths', () async {
      final tempDir = await Directory.systemTemp.createTemp('translator_dart_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourceDir = Directory(
        '${joinAppPath(tempDir.path, kRelativeAndroidMetadataDir)}/$kAndroidMetadataSourceLocale',
      );
      await sourceDir.create(recursive: true);
      await File('${sourceDir.path}/title.txt').writeAsString('Mamesama');
      await File('${sourceDir.path}/video.txt').writeAsString('https://x.test');
      final changelogFile = File('${sourceDir.path}/changelogs/default.txt');
      await changelogFile.parent.create(recursive: true);
      await changelogFile.writeAsString('Fixed bugs');

      final task = AndroidMetadataTranslation(
        appDirectory: tempDir.path,
        relativePaths: const ['changelogs/default.txt'],
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async => 'translated',
        ),
      );

      await task.run();

      final frMetadataDir = joinAppPath(
        tempDir.path,
        '$kRelativeAndroidMetadataDir/fr-FR',
      );

      expect(
        await File('$frMetadataDir/changelogs/default.txt').exists(),
        isTrue,
      );
      expect(
        await File('$frMetadataDir/changelogs/default.txt').readAsString(),
        'translated',
      );
      expect(await File('$frMetadataDir/title.txt').exists(), isFalse);
      expect(await File('$frMetadataDir/video.txt').exists(), isFalse);
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
