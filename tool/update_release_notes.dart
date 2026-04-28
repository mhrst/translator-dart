#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:translator_dart/translator_dart.dart';

const _usage = '''
Prompts for updated English release notes, writes them to this Flutter app's
metadata sources, and force-translates only the release-note files.

Usage:
  dart run tool/update_release_notes.dart

Options:
  -h, --help   Show this help.
''';

Future<void> main(List<String> args) async {
  final configuration = _parseArgs(args);
  if (configuration.showHelp) {
    stdout.write(_usage);
    return;
  }

  final releaseNotes = await _readReleaseNotes();
  if (releaseNotes.trim().isEmpty) {
    stderr.writeln('Release notes cannot be empty.');
    exitCode = 64;
    return;
  }

  try {
    final appDirectory = Directory.current.path;
    final iosReleaseNotesFile = File(
      joinAppPath(
        appDirectory,
        '$kRelativeIosMetadataDir/'
        '$kIosMetadataSourceLocale/release_notes.txt',
      ),
    );
    final androidReleaseNotesFile = File(
      joinAppPath(
        appDirectory,
        '$kRelativeAndroidMetadataDir/'
        '$kAndroidMetadataSourceLocale/changelogs/default.txt',
      ),
    );

    await _writeReleaseNotes(iosReleaseNotesFile, releaseNotes);
    await _writeReleaseNotes(androidReleaseNotesFile, releaseNotes);

    stdout.writeln('Updated ${iosReleaseNotesFile.path}');
    stdout.writeln('Updated ${androidReleaseNotesFile.path}');

    await IosMetadataTranslation(
      appDirectory: appDirectory,
      filename: 'release_notes.txt',
      force: true,
    ).run();
    await AndroidMetadataTranslation(
      appDirectory: appDirectory,
      relativePaths: const ['changelogs/default.txt'],
      force: true,
    ).run();

    stdout.writeln(
      'Forced release-note translations for iOS and Android metadata.',
    );
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    if (error.path != null) {
      stderr.writeln(error.path);
    }
    exitCode = 2;
  }
}

_Configuration _parseArgs(List<String> args) {
  var showHelp = false;

  for (final arg in args) {
    switch (arg) {
      case '--help':
      case '-h':
        showHelp = true;
        break;
      default:
        stderr.writeln('Unexpected argument: $arg');
        stderr.write(_usage);
        exitCode = 64;
        return const _Configuration(showHelp: false);
    }
  }

  return _Configuration(showHelp: showHelp);
}

Future<String> _readReleaseNotes() async {
  if (!stdin.hasTerminal) {
    return (await stdin.transform(utf8.decoder).join()).trimRight();
  }

  stdout.writeln(
    'Paste the updated English release notes. Finish with EOF or a single "." line.',
  );

  final lines = <String>[];
  while (true) {
    final line = stdin.readLineSync();
    if (line == null || line == '.') {
      break;
    }
    lines.add(line);
  }

  return lines.join('\n').trimRight();
}

Future<void> _writeReleaseNotes(File file, String content) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(content, encoding: utf8);
}

class _Configuration {
  final bool showHelp;

  const _Configuration({this.showHelp = false});
}
