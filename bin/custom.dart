import 'dart:io';

import 'package:localization_sheets/localization_sheets.dart';

Future<void> main() async {
  Directory.current = '/Users/pszot/Documents/projects/messefrankfurt-ios';
  final config = Config.fromCurrentDirectory();
  config.skipCache = true;
  await run(config);
}
