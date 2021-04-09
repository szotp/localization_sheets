import 'dart:io';

import 'package:path/path.dart' as p;

extension FileSystemEntityExt on FileSystemEntity {
  String get basename => p.basename(path);
  String get basenameWithoutExtension => p.basenameWithoutExtension(path);
  String get extension => p.extension(path);
}

extension FileExt on File {
  File replacingExtension(String extension) {
    return File(p.setExtension(path, extension));
  }

  File replacingName(String name) {
    return File(p.join(parent.path, name));
  }

  void ensureDirectoryExists() {
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
  }
}

extension DirectoryExt on Directory {
  File childFile(String basename) => File(p.join(path, basename));
  Directory childDirectory(String basename) =>
      Directory(p.join(path, basename));
}
