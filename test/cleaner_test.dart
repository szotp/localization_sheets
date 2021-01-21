import 'dart:io';

import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:test/test.dart';
import '../bin/arb_cleanup.dart' as arb_cleanup;

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

    expect(current.snapshot(), target.snapshot());
  });

  test('example_flutter', () {
    Directory.current = '../example_flutter';
    arb_cleanup.main([]);
  });

  test('ios import', () {
    final strings = File('files/ios_strings/en.lproj/Localizable.strings').absolute;
    assert(strings.existsSync());

    Directory.current = (temp.childDirectory('ios_test')..createSync(recursive: true));
    arb_cleanup.main(['--import_ios_strings', strings.path]);

    expect(Directory.current.snapshot(includeChecksums: false), [
      '/assets',
      '/assets/languages',
      '/assets/languages/en.arb',
      '/assets/languages/pl.arb',
    ]);
  });
}
