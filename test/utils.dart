import 'dart:io';

import 'package:localization_sheets/file_ext.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

export 'package:localization_sheets/file_ext.dart';

final temp = Directory('files/temp');

Directory _initial;
void _normalizeCurrentDirectory() {
  _initial ??= Directory.current;
  if (_initial.basename != 'test') {
    _initial = Directory('test');
  }

  Directory.current = _initial;
  assert(Directory.current.existsSync());
}

/// Ensures that tests execute in test directory
void normalizeCurrentDirectory() {
  final dir = Directory.current;
  setUp(() {
    _normalizeCurrentDirectory();

    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });
  tearDown(() {
    Directory.current = dir;
  });
}

void runCommand(String command, List<String> arguments) {
  final result = Process.runSync(
    command,
    arguments,
    includeParentEnvironment: true,
  );

  print(result.stdout);
  print(result.stderr);
  expect(result.exitCode, 0);
}

extension SnapshotExt on Directory {
  List<String> snapshot({bool includeChecksums = true}) {
    return listSync(recursive: true)
        .map((e) {
          final name = e.path.replaceFirst(path, '');

          if (e is Directory) {
            return name;
          }

          if (e is File && e.extension == '.arb') {
            if (includeChecksums) {
              return '$name : ${e.calculateChecksum().substring(0, 6)}';
            } else {
              return name;
            }
          }

          return null;
        })
        .where((element) => element != null)
        .toList();
  }
}

extension on File {
  String calculateChecksum() {
    return sha256.convert(readAsBytesSync()).toString();
  }
}
