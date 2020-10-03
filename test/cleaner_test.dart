import 'dart:io';

import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:test/test.dart';
import 'package:localization_sheets/file_ext.dart';
import 'package:crypto/crypto.dart';

void main() {
  if (Directory.current.basename != 'test') {
    Directory.current = 'test';
  }

  test('cleaner works', () {
    final project = loadProject(
      directory: Directory('files'),
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
    expect(project.defaultTemplate == 'en', true);
    insertDescriptions(project);

    final target = Directory('files_target');
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
