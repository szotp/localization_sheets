import 'dart:io';

import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:test/test.dart';
import 'package:localization_sheets/file_ext.dart';
import 'package:crypto/crypto.dart';

Directory _initial;
void normalizeCurrentDirectory() {
  _initial ??= Directory.current;
  if (_initial.basename != 'test') {
    _initial = Directory('test');
  }

  Directory.current = _initial;
  assert(Directory.current.existsSync());
}

void main() {
  test('cleaner works', () {
    normalizeCurrentDirectory();
    final project = loadProject(
      directory: Directory('files'),
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
    expect(project.defaultTemplate == 'en', true);
    insertDescriptions(project);

    final target = Directory('../example_flutter/assets/languages');
    final current = Directory('temp/files_current');

    if (!target.existsSync()) {
      print('Target missing. Regenerating...');
      saveProject(project, target);
    }

    if (current.existsSync()) {
      current.deleteSync(recursive: true);
    }
    saveProject(project, current);

    expect(snapshot(current), snapshot(target));
  });

  test('cleaner command', () {
    normalizeCurrentDirectory();
    Directory.current = '../example_flutter';

    runCommand(
      'flutter',
      'pub get'.split(' '),
    );

    runCommand(
      'flutter',
      'pub run arb_cleanup'.split(' '),
    );
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
