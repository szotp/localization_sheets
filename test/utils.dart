import 'dart:io';

import 'package:localization_sheets/file_ext.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

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

String snapshot(Directory dir) {
  return dir
      .listSync()
      .where((x) => x.extension == '.arb')
      .map((x) => '${x.basename}: ${(x as File).calculateChecksum()}')
      .join('\n');
}

extension on File {
  String calculateChecksum() {
    return sha256.convert(readAsBytesSync()).toString();
  }
}
