import 'dart:io';

const kRelativeL10nDir = 'lib/src/localization';
const kFlutterDefaultRelativeL10nDir = 'lib/l10n';
const kDefaultTemplateArbFile = 'app_en.arb';
const kRelativeIosRunnerDir = 'ios/Runner';
const kRelativeIosMetadataDir = 'ios/fastlane/metadata';
const kRelativeAndroidResDir = 'android/app/src/main/res';
const kRelativeAndroidMetadataDir = 'android/fastlane/metadata/android';

class L10nConfiguration {
  final String relativeArbDir;
  final String templateArbFile;

  const L10nConfiguration({
    required this.relativeArbDir,
    required this.templateArbFile,
  });

  String arbDirectoryPath(String appDir) {
    return joinAppPath(appDir, relativeArbDir);
  }
}

L10nConfiguration resolveL10nConfiguration(String appDir) {
  final l10nYaml = File(joinAppPath(appDir, 'l10n.yaml'));
  if (l10nYaml.existsSync()) {
    final entries = _readSimpleYamlMap(l10nYaml);
    return L10nConfiguration(
      relativeArbDir: entries['arb-dir'] ?? kFlutterDefaultRelativeL10nDir,
      templateArbFile: entries['template-arb-file'] ?? kDefaultTemplateArbFile,
    );
  }

  final flutterDefaultTemplate = File(
    joinAppPath(
      appDir,
      '$kFlutterDefaultRelativeL10nDir/$kDefaultTemplateArbFile',
    ),
  );
  if (flutterDefaultTemplate.existsSync()) {
    return const L10nConfiguration(
      relativeArbDir: kFlutterDefaultRelativeL10nDir,
      templateArbFile: kDefaultTemplateArbFile,
    );
  }

  return const L10nConfiguration(
    relativeArbDir: kRelativeL10nDir,
    templateArbFile: kDefaultTemplateArbFile,
  );
}

String joinAppPath(String appDir, String relativePath) {
  final needsTrim =
      appDir.endsWith('/') || appDir.endsWith(Platform.pathSeparator);
  final normalizedAppDir = needsTrim
      ? appDir.substring(0, appDir.length - 1)
      : appDir;
  final normalizedRelative = relativePath.replaceAll(
    '/',
    Platform.pathSeparator,
  );
  return '$normalizedAppDir${Platform.pathSeparator}$normalizedRelative';
}

Map<String, String> _readSimpleYamlMap(File file) {
  final entries = <String, String>{};
  final entryPattern = RegExp(r'^([A-Za-z0-9_-]+):\s*(.*?)\s*$');

  for (final rawLine in file.readAsLinesSync()) {
    final line = _stripYamlComment(rawLine).trim();
    if (line.isEmpty) {
      continue;
    }

    final match = entryPattern.firstMatch(line);
    if (match == null) {
      continue;
    }

    entries[match.group(1)!] = _stripYamlQuotes(match.group(2)!.trim());
  }

  return entries;
}

String _stripYamlComment(String line) {
  var inSingleQuotes = false;
  var inDoubleQuotes = false;

  for (var i = 0; i < line.length; i += 1) {
    final char = line[i];
    if (char == "'" && !inDoubleQuotes) {
      inSingleQuotes = !inSingleQuotes;
    } else if (char == '"' && !inSingleQuotes) {
      inDoubleQuotes = !inDoubleQuotes;
    } else if (char == '#' && !inSingleQuotes && !inDoubleQuotes) {
      return line.substring(0, i);
    }
  }

  return line;
}

String _stripYamlQuotes(String value) {
  if (value.length < 2) {
    return value;
  }

  final first = value[0];
  final last = value[value.length - 1];
  if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
    return value.substring(1, value.length - 1);
  }

  return value;
}
