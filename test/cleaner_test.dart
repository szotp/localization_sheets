import 'dart:io';

import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  normalizeCurrentDirectory();

  test('cleaner works', () {
    final project = loadProject(
      directory: Directory('files/arb_dirty'),
      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
    expect(project.defaultTemplate == 'en', true);
    insertDescriptions(project);

    final target = Directory('../example_flutter/assets/languages');
    final current = Directory('files/temp/files_current');

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

  // test('cleaner command', () {
  //   normalizeCurrentDirectory();
  //   Directory.current = '../example_flutter';

  //   runCommand(
  //     'flutter',
  //     'pub get'.split(' '),
  //   );

  //   runCommand(
  //     'flutter',
  //     'pub run arb_cleanup'.split(' '),
  //   );
  // });
}
