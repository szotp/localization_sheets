import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:arb/models/arb_document.dart';
import 'package:arb/models/arb_project.dart';
import 'package:arb/models/arb_resource.dart';
import 'package:localization_sheets/localization_sheets.dart';
import 'package:localization_sheets/file_ext.dart';
import 'package:recase/recase.dart';

import 'strings_to_arb.dart';

/// Parses arb files and prints them as tsv
void parseArb() {
  final c = currentConfig;

  final dir = Directory(c.outputPath!);

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

Map<String, dynamic> flatten(Map<String, dynamic>? input) {
  final r = <String, dynamic>{};
  _flatten(input, r, '');
  return r;
}

void _flatten(
    Map<String, dynamic>? input, Map<String, dynamic> results, String prefix) {
  if (input == null) {
    return;
  }

  for (final entry in input.entries) {
    if (entry.value is String || entry.key.startsWith('@')) {
      results[prefix + entry.key] = entry.value;
      continue;
    }

    final newPrefix = '$prefix${prefix.isEmpty ? '' : '_'}${entry.key}_';
    final valueMap = entry.value as Map<String, dynamic>?;
    _flatten(valueMap, results, newPrefix);
  }
}

Map<String, dynamic> removeAttributesForNonExistingKeys(
    Map<String, dynamic> map) {
  final copy = Map<String, dynamic>.from(map);

  copy.removeWhere((key, value) {
    if (key.startsWith('@') && !key.startsWith('@@')) {
      return !map.containsKey(key.substring(1));
    }

    return false;
  });

  return copy;
}

Map<String, dynamic> recaseKeys(Map<String, dynamic> input) {
  final usedKey = <String>{};

  return input.map((k, v) {
    if (!k.startsWith('@')) {
      k = ArbProcessor.recase(k);
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

extension ArbProjectExt on ArbProject {
  Map<String, ArbResource> get defaultResources {
    return documents
        .firstWhere((element) => element.locale == defaultTemplate)
        .resources;
  }
}

// ignore: avoid_classes_with_only_static_members
class ArbProcessor {
  // ignore: prefer_function_declarations_over_variables
  static String Function(String) recase = (x) => x.camelCase;

  static ArbProject merge(List<ArbProject> projects, List<String> specifiers) {
    final docs = <String, ArbDocument>{};

    for (final p in projects) {
      p.defaultTemplate = 'en';
    }

    final duplicates = projects
        .map((e) => e.defaultResources.keys)
        .expand((element) => element)
        .toSet();

    duplicates.removeWhere((key) {
      final values =
          projects.map((e) => e.defaultResources[key]?.value.text).toSet();
      values.remove(null);
      if (values.length > 1) {
        print('$key $values');
      }
      return values.length == 1;
    });

    if (duplicates.isNotEmpty) {
      print('Differing values: $duplicates');
    }

    for (final p in projects) {
      for (final document in p.documents) {
        final Map<String, ArbResource?> newResources = docs
            .putIfAbsent(document.locale, () => ArbDocument(document.locale))
            .resources;

        for (var key in document.resources.keys) {
          final entry = document.resources[key];
          if (duplicates.contains(key)) {
            key = '$key${specifiers[projects.indexOf(p)]}';
          }

          newResources[key] = entry;
        }
      }
    }

    final doc = docs.values.toList();

    doc.sort((a, b) => a.locale.compareTo(b.locale));
    final defaultIndex = doc.indexWhere(
        (element) => element.locale == projects.first.defaultTemplate);
    doc.insert(0, doc.removeAt(defaultIndex));

    return ArbProject('x', documents: doc);
  }

  static ArbProject loadIosStrings(String templatePath) =>
      parseStrings(templatePath);

  static ArbProject loadProject({
    String defaultLocale = 'en',
    Directory? directory,
    DateTime? lastModified,
    String extension = '.arb',
  }) {
    final docs = <ArbDocument>[];

    directory ??= Directory.current;

    for (final file in directory.listSync()) {
      if (file.extension == extension) {
        final content = (file as File).readAsStringSync();
        var map = jsonDecode(content) as Map<String, dynamic>?;
        map = flatten(map);
        map = recaseKeys(map);
        map = removeAttributesForNonExistingKeys(map);

        final doc =
            ArbDocument.fromJson(map, locale: file.basenameWithoutExtension);
        if (lastModified != null) {
          doc.lastModified = lastModified;
        }

        assert(doc.locale == file.basenameWithoutExtension);
        docs.add(doc);
      }
    }

    final proj = ArbProject('$defaultLocale$extension', documents: docs);
    proj.defaultTemplate = defaultLocale;
    return proj;
  }

  static void printTsv(ArbProject merged, List<String> languageOrder) {
    final buffer = StringBuffer();

    final documents = merged.documents.toList();

    documents.sort((a, b) {
      final ai = languageOrder.indexOf(a.locale);
      final bi = languageOrder.indexOf(b.locale);
      assert(ai != -1);
      assert(bi != -1);
      return ai.compareTo(bi);
    });

    final languages = documents.map((e) => e.locale);

    buffer.writeln(['key', ...languages].join('\t'));

    final keys = merged.resources.keys.toList();
    keys.sort();

    for (final key in keys) {
      final values = [
        key,
        ...documents.map((e) => e.resources[key]?.value.text ?? ''),
      ];

      buffer.writeln(values.join('\t'));
    }

    File('file.tsv').writeAsStringSync(buffer.toString());
  }
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
  final allKeys = project
      .mapDocuments[project.defaultTemplate]!.resources.values
      .map((x) => x.id)
      .toSet();

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
