#!/usr/bin/env dart

import 'dart:io';

import 'package:translator_dart/translator_dart.dart';

const _usage = '''
Translates Android metadata and native strings for this Flutter app.

Usage:
  dart run tool/translate_android.dart [--force]

Options:
  --force      Re-translate existing Android translations.
  -h, --help   Show this help.
''';

Future<void> main(List<String> args) async {
  final configuration = _parseArgs(args);
  if (configuration.showHelp) {
    stdout.write(_usage);
    return;
  }

  try {
    final appDirectory = Directory.current.path;
    await AndroidMetadataTranslation(
      appDirectory: appDirectory,
      force: configuration.force,
    ).run();
    await AndroidStringsTranslation(
      appDirectory: appDirectory,
      force: configuration.force,
    ).run();
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    if (error.path != null) {
      stderr.writeln(error.path);
    }
    exitCode = 2;
  }
}

_Configuration _parseArgs(List<String> args) {
  var force = false;
  var showHelp = false;

  for (final arg in args) {
    switch (arg) {
      case '--force':
        force = true;
        break;
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

  return _Configuration(force: force, showHelp: showHelp);
}

class _Configuration {
  final bool force;
  final bool showHelp;

  const _Configuration({this.force = false, this.showHelp = false});
}
