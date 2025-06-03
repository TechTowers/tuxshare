import 'dart:io';

String getDefaultDownloadsPath() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      return '$userProfile\\Downloads';
    }
  } else {
    final home = Platform.environment['HOME'];
    if (home != null) {
      return '$home/Downloads';
    }
  }

  // Fallback to current directory if all else fails
  return Directory.current.path;
}

String expandHome(String path) {
  if (path.startsWith('~')) {
    final home =
        Platform.isWindows
            ? Platform.environment['USERPROFILE']
            : Platform.environment['HOME'];
    if (home != null) {
      return path.replaceFirst('~', home);
    }
  }
  return path;
}

String resolveDestinationPath(String outputPath, String originalFilename) {
  String input = outputPath.trim();
  if (input.endsWith(Platform.pathSeparator)) {
    input = input.substring(0, input.length - 1);
  }

  final expanded = expandHome(input);
  final fileOrDir = File(expanded);
  final dir = Directory(expanded);

  if (input.isEmpty) {
    return '${getDefaultDownloadsPath()}${Platform.pathSeparator}$originalFilename';
  }

  if (dir.existsSync()) {
    return '${dir.path}${Platform.pathSeparator}$originalFilename';
  } else if (fileOrDir.parent.existsSync()) {
    return fileOrDir.path;
  } else {
    return '${getDefaultDownloadsPath()}${Platform.pathSeparator}$input';
  }
}
