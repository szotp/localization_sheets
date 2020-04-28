import 'dart:convert';
import 'dart:io';
import 'package:localization_sheets/localization_sheets.dart';

/// Parses arb files and prints them as tsv
void parseArb() {
  final c = currentConfig;

  final dir = Directory(c.outputPath);

  for (var item in dir.listSync()) {
    if (item is Directory) {
      for (var item2 in item.listSync()) {
        if (item2 is File && item2.path.endsWith('arb')) {
          final jsonString = item2.readAsStringSync();
          final dict = json.decode(jsonString) as Map<String, dynamic>;

          for (var key in dict.keys) {
            final value = dict[key].toString().replaceAll('\n', '\\n');
            print('$key\t$value');
          }
        }
      }
    }
  }
}
