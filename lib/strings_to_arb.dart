import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:arb/dart_arb.dart';
import 'package:recase/recase.dart';

extension FileSystemEntityExt on FileSystemEntity {
  String get basename => p.basename(path);
  String get basenameWithoutExtension => p.basenameWithoutExtension(path);
  String get extension => p.extension(path);
}

extension FileExt on File {
  File replacingExtension(String extension) {
    return File(p.setExtension(path, extension));
  }

  File replacingName(String name) {
    return File(p.join(parent.path, name));
  }
}

extension DirectoryExt on Directory {
  File childFile(String basename) => File(p.join(path, basename));
  Directory childDirectory(String basename) =>
      Directory(p.join(path, basename));
}

final placeholders = RegExp(r'%[@dfs]');
final forbidden = RegExp('[!(){};\'\",:&#]');

ArbDocument _parseArbDocument(File file, String language) {
  final doc = StringEnumerator(file.readAsStringSync());

  final Map<String, ArbResource> resources = {};

  const delimiter = '\"';

  while (!doc.eof) {
    final peek = doc.peek;

    if (peek == '/') {
      doc.popExpecting('/');

      final next = doc.pop();
      if (next == '/') {
        doc.popLine();
        continue;
      }

      if (next == '*') {
        doc.ignoreUntilIncluding('*/');
        continue;
      }

      assert(false);
    }

    if (peek.trim().isEmpty) {
      doc.pop();
      continue;
    }

    var key = doc.popString(delimiter);
    doc.popWhitespace();
    doc.popExpecting('=');
    doc.popWhitespace();

    var value = doc.popString(delimiter);

    key = sanitizeKey(key);
    value = sanitizeValue(value);

    doc.popExpecting(';');
    resources[key] = ArbResource(key, value);
  }

  return ArbDocument(language, resources: resources);
}

String sanitizeValue(String valuep) {
  int index = 1;
  return valuep.replaceAllMapped(placeholders, (x) => '{arg${index++}}');
}

String sanitizeKey(String keyp) {
  String key = keyp;

  const items = 'XYZXYZ';
  int index = 0;

  key = key.replaceAllMapped(placeholders, (x) => items[index++]);
  key = key.replaceAll(forbidden, '_');
  key = key.replaceAll('\"', '_');
  key = key.camelCase;

  return key;
}

Iterable<ArbDocument> _parseArbDocuments(
    Directory directory, String basename) sync* {
  for (final lproj in directory.listSync()) {
    if (lproj.path.endsWith('.lproj')) {
      final language = lproj.basenameWithoutExtension;
      final languageFile = (lproj as Directory).childFile(basename);

      if (languageFile.existsSync()) {
        yield _parseArbDocument(languageFile, language);
      }
    }
  }
}

ArbProject parseStrings(String templateFile) {
  final file = File(templateFile);
  final directory = file.parent.parent;
  final docs = _parseArbDocuments(directory, file.basename).toList();

  return ArbProject(
    file.basename,
    documents: docs,
  );
}

class StringEnumerator {
  final String content;
  int index = 0;

  int line = 1;
  int column = 1;

  StringEnumerator(this.content);

  bool get eof => (content.length - 1) <= index;

  String get peek => content[index];

  String pop() {
    final result = content[index++];
    column++;
    if (result == '\n') {
      line++;
      column = 1;
    }
    return result;
  }

  String popLine() {
    final buffer = StringBuffer();

    while (!eof && peek != '\n') {
      buffer.write(pop());
    }

    if (!eof) {
      popExpecting('\n');
    }

    return buffer.toString();
  }

  void ignoreUntilIncluding(String characters) {
    while (!eof) {
      if (pop() != characters[0]) {
        continue;
      }

      final matches =
          content.substring(index - 1, index - 1 + characters.length) ==
              characters;
      if (matches) {
        for (int i = 1; i < characters.length; i++) {
          pop();
        }

        return;
      }
    }
  }

  String popExpecting(String expects) {
    final result = pop();
    assert(result == expects, '$line:$column: expected: $expects got: $result');
    return result;
  }

  void popWhitespace() {
    while (!eof && peek.trim().isEmpty) {
      pop();
    }
  }

  String popString(String delimiter) {
    popExpecting(delimiter);

    final buffer = StringBuffer();
    while (peek != delimiter) {
      var popped = pop();

      if (popped == '\\') {
        popped = pop();
      }

      buffer.write(popped);
    }

    popExpecting(delimiter);
    return buffer.toString();
  }
}

void stringsToArb(File template, Directory targetDirectory) {
  final results = parseStrings(template.path);

  for (final doc in results.documents) {
    final sortedKeys = doc.resources.keys.toList();
    sortedKeys.sort();
    final json = {
      for (final key in sortedKeys) key: doc.resources[key].value.text,
    };

    final targetFile = targetDirectory.childFile('${doc.locale}.arb');
    const encoder = JsonEncoder.withIndent('  ');
    targetFile.writeAsStringSync(encoder.convert(json));
  }
}
