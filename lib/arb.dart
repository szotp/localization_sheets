import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:arb/models/arb_document.dart';
import 'package:arb/models/arb_project.dart';
import 'package:localization_sheets/localization_sheets.dart';
import 'package:localization_sheets/file_ext.dart';
import 'package:recase/recase.dart';

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

Map<String, dynamic> flatten(Map<String, dynamic> input) {
  final r = <String, dynamic>{};
  _flatten(input, r, '');
  return r;
}

void _flatten(Map<String, dynamic> input, Map<String, dynamic> results, String prefix) {
  if (input == null) {
    return;
  }

  for (final entry in input.entries) {
    if (entry.value is String || entry.key.startsWith('@')) {
      results[prefix + entry.key] = entry.value;
      continue;
    }

    final newPrefix = '$prefix${prefix.isEmpty ? '' : '_'}${entry.key}_';
    final valueMap = entry.value as Map<String, dynamic>;
    _flatten(valueMap, results, newPrefix);
  }
}

Map<String, dynamic> recaseKeys(Map<String, dynamic> input) {
  final usedKey = <String>{};

  return input.map((k, v) {
    if (!k.startsWith('@')) {
      k = k.camelCase;

      if (usedKey.contains(k)) {
        int counter = 2;
        while (usedKey.contains('$k$counter')) {
          counter++;
        }
        k = '$k$counter';
      }
    }

    usedKey.add(k);
    return MapEntry(k, v);
  });
}

ArbProject loadProject({
  String defaultLocale = 'en',
  Directory directory,
  DateTime lastModified,
  String extension = '.arb',
}) {
  final docs = <ArbDocument>[];

  directory ??= Directory.current;

  for (final file in directory.listSync()) {
    if (file.extension == extension) {
      final content = (file as File).readAsStringSync();
      var map = jsonDecode(content) as Map<String, dynamic>;
      map = flatten(map);
      map = recaseKeys(map);

      final doc = ArbDocument.fromJson(map);
      if (lastModified != null) {
        doc.lastModified = lastModified;
      }

      doc.locale ??= file.basenameWithoutExtension;
      assert(doc.locale == file.basenameWithoutExtension);
      docs.add(doc);
    }
  }

  final proj = ArbProject('$defaultLocale.arb', documents: docs);
  proj.defaultTemplate = defaultLocale;
  return proj;
}

enum KeyKind { metaMeta, normal, meta }

KeyKind getKind(String key) {
  if (key.startsWith('@')) {
    if (key.startsWith('@@')) {
      return KeyKind.metaMeta;
    } else {
      return KeyKind.meta;
    }
  } else {
    return KeyKind.normal;
  }
}

int compareKeys(String a, String b) {
  final byKind = getKind(a).index.compareTo(getKind(b).index);
  if (byKind == 0) {
    return a.compareTo(b);
  } else {
    return byKind;
  }
}

void saveProject(ArbProject project, Directory targetDirectory) {
  final allKeys = project.mapDocuments[project.defaultTemplate].resources.values.map((x) => x.id).toSet();

  if (!targetDirectory.existsSync()) {
    targetDirectory.createSync(recursive: true);
  }

  for (final doc in project.documents) {
    final targetFile = targetDirectory.childFile('${doc.locale}.arb');

    var json = doc.toJson();
    json = SplayTreeMap(compareKeys)..addAll(json);

    if (doc.locale != project.defaultTemplate) {
      json.removeWhere((k, v) => getKind(k) == KeyKind.meta);

      for (final key in allKeys) {
        if (!json.containsKey(key)) {
          json[key] = null;
        }
      }
    }

    const encoder = JsonEncoder.withIndent('    ');
    targetFile.ensureDirectoryExists();
    targetFile.writeAsStringSync(encoder.convert(json));
  }
}
