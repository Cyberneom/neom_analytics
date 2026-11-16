Map<String, String> readPlatformEnvironment() => const <String, String>{};

bool isLinkSyncSafe(String path) => false;

Future<void> writeOwnerOnlyFileNative(
  String trimmedPath,
  String normalizedPath,
  String contents,
  Map<String, String> subprocessEnv,
) async {
  // No-op on Web where POSIX files and chmod are unavailable.
}
