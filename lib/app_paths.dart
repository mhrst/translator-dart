import 'dart:io';

const kRelativeL10nDir = 'lib/src/localization';
const kRelativeIosRunnerDir = 'ios/Runner';
const kRelativeIosMetadataDir = 'ios/fastlane/metadata';
const kRelativeAndroidResDir = 'android/app/src/main/res';
const kRelativeAndroidMetadataDir = 'android/fastlane/metadata/android';

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
