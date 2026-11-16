import 'dart:async';
import 'dart:io';

Map<String, String> readPlatformEnvironment() => Platform.environment;

bool isLinkSyncSafe(String path) => FileSystemEntity.isLinkSync(path);

bool _hasAnySymlinkAncestorIo(String normalizedPath) {
  final isAbs = normalizedPath.startsWith('/');
  final parts = normalizedPath.split('/').where((s) => s.isNotEmpty).toList();
  var accum = isAbs ? '' : '.';
  final allowDarwinRootAlias = Platform.isMacOS || Platform.isIOS;
  for (final part in parts) {
    accum = accum.isEmpty
        ? '/$part'
        : (accum == '.' ? part : '$accum/$part');
    if (allowDarwinRootAlias && (accum == '/var' || accum == '/tmp')) {
      continue;
    }
    if (FileSystemEntity.isLinkSync(accum) ||
        FileSystemEntity.typeSync(accum, followLinks: false) ==
            FileSystemEntityType.link) {
      return true;
    }
  }
  return false;
}

Future<void> writeOwnerOnlyFileNative(
  String trimmedPath,
  String normalizedPath,
  String contents,
  Map<String, String> subprocessEnv,
) async {
  if (_hasAnySymlinkAncestorIo(normalizedPath)) {
    throw FileSystemException(
      'Refusing to write PII export through symlink',
      trimmedPath,
    );
  }
  final file = File(trimmedPath);
  await file.writeAsString(contents);
  if (!Platform.isWindows && (Platform.isMacOS || Platform.isLinux)) {
    try {
      await Process.run(
        'chmod',
        <String>['600', trimmedPath],
        runInShell: false,
        includeParentEnvironment: false,
        environment: subprocessEnv,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
