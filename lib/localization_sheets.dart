import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:googleapis/drive/v3.dart' as google;
import 'package:googleapis_auth/auth_io.dart' as google;
import 'package:localization_sheets/storage.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

Future<google.AutoRefreshingAuthClient> obtainClient() async {
  final id = google.ClientId(
    '811930618997-macl0qns0knf1gamvlrqt8npklnajido.apps.googleusercontent.com',
    'd0Ov2Kq8Y6e3bhGWaaD60F_X',
  );

  final scopes = <String>['https://www.googleapis.com/auth/drive.readonly'];

  final google.AccessCredentials credentials = loadCredentials();

  if (credentials != null &&
      const ListEquality().equals(scopes, credentials.scopes)) {
    return google.autoRefreshingClient(id, credentials, http.Client());
  }

  final client = await google.clientViaUserConsent(id, scopes, prompt);
  saveCredentials(client.credentials);

  return client;
}

Future<SpreadsheetDecoder> loadSpreadSheet(String fileId) async {
  final client = await obtainClient();
  final api = google.DriveApi(client);

  final google.File meta =
      await api.files.get(fileId, $fields: 'modifiedTime, name') as google.File;

  final file = File('${getHomePath()}/${meta.name}.ods');

  var skipCache = currentConfig.skipCache;

  assert(() {
    //we usually want to skip cache when changing the script
    skipCache = false;
    return true;
  }());

  if (file.existsSync() &&
      file.lastModifiedSync().isAfter(meta.modifiedTime) &&
      !skipCache) {
    print('Using cached file...');
    final bytes = file.readAsBytesSync();
    return SpreadsheetDecoder.decodeBytes(bytes);
  }

  print('Downloading spreadsheet...');
  final google.Media media = await api.files.export(
    fileId,
    'application/x-vnd.oasis.opendocument.spreadsheet',
    downloadOptions: google.DownloadOptions.FullMedia,
  ) as google.Media;

  final bytes = Uint8List(media.length);
  int i = 0;

  await media.stream.forEach((part) {
    for (var b in part) {
      bytes[i++] = b;
    }
  });

  file.writeAsBytesSync(bytes);
  file.setLastModifiedSync(meta.modifiedTime.add(const Duration(seconds: 1)));

  assert(bytes.lengthInBytes == media.length);
  client.close();
  return SpreadsheetDecoder.decodeBytes(bytes);
}

bool isLanguageSpecifier(String h) {
  if (h == null) {
    return false;
  }
  return h.length == 2 || h.length == 5 && h[2] == '-';
}

final _regexSnakeCaseToCamelCase = RegExp(r'[\._].');

String convertKey(String key) {
  if (!currentConfig.snakeCaseToCamelCase) {
    return key;
  }

  final result = key.replaceAllMapped(_regexSnakeCaseToCamelCase, (x) {
    return x.group(0)[1].toUpperCase();
  });

  return result.replaceRange(0, 1, result[0].toLowerCase());
}

Iterable<LocalizationsTable> buildMap(SpreadsheetDecoder data) sync* {
  final config = currentConfig;

  final startColumn = config.headerColumns;
  final startRow = config.headerRows;
  const keyColumn = 0;
  for (var name in data.tables.keys) {
    if (config.sheets?.isNotEmpty == true) {
      if (!config.sheets.contains(name)) {
        continue;
      }
    }

    final table = data.tables[name];

    if (config.nameMap.containsKey(name)) {
      name = config.nameMap[name];
      if (name == '') {
        continue;
      }
    }

    final header = table.rows[0];

    final Map<String, SplayTreeMap<String, String>> map = {};

    for (int column = startColumn; column < table.maxCols; column++) {
      final h = header[column].toString().trim();
      if (isLanguageSpecifier(h)) {
        map[h] = SplayTreeMap();
      }
    }

    for (int row = startRow; row < table.maxRows; row++) {
      final rowData = table.rows[row];
      final String key = (rowData[keyColumn] as String)?.trim();

      for (int column = startColumn; column < table.maxCols; column++) {
        final String language = (header[column] as String)?.trim();
        final String value = rowData[column] as String;

        final langMap = map[language];
        if (langMap != null &&
            key != null &&
            key.isNotEmpty &&
            value != '!not relevant!') {
          langMap[convertKey(key)] = value;
        }
      }
    }

    if (currentConfig.languageForDefaults != null) {
      final defaults = map[currentConfig.languageForDefaults];

      for (final mapForLanguage in map.values) {
        if (mapForLanguage == defaults) {
          continue;
        }

        final nulls = mapForLanguage.entries
            .where((x) => x.value == null)
            .map((x) => x.key)
            .toList();

        for (final key in nulls) {
          mapForLanguage[key] = defaults[key];
        }
      }
    }

    yield LocalizationsTable(name, map);
  }
}

void saveArb(SpreadsheetDecoder data) {
  final tables = buildMap(data).toList();
  //deleteOut();

  for (var table in tables) {
    for (var language in table.languages) {
      String path = currentConfig.outputPath;

      path = p.join(path, table.name);
      path = p.join(path, '$language.arb');

      final file = File(path);
      file.createSync(recursive: true);
      final Map<String, String> langMap = table.mapForSerialization(language);
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(langMap);
      file.writeAsStringSync(jsonString);

      print('Writing $file');
    }
  }
}

void deleteOut() {
  final fileOut = Directory(currentConfig.outputPath);
  if (fileOut.existsSync()) {
    File(currentConfig.outputPath).deleteSync(recursive: true);
  }
}

enum ExportFormat { arb, strings, android }

ExportFormat exportFormatFromJson(String json) {
  for (var value in ExportFormat.values) {
    if (value.toString() == json) {
      return value;
    }
  }

  throw 'unknown ExportFormat: $json';
}

class Config {
  Map<String, String> nameMap;
  List<String> skipLanguages;
  ExportFormat format;
  String outputPath;
  String id;
  bool skipCache;
  bool snakeCaseToCamelCase;
  int headerRows;
  int headerColumns;
  List<String> sheets;
  String languageForDefaults;

  Config({
    @required this.nameMap,
    @required this.skipLanguages,
    @required this.format,
    @required this.outputPath,
    @required this.id,
    this.skipCache,
    this.snakeCaseToCamelCase,
    this.headerRows,
    this.headerColumns,
    this.sheets,
    this.languageForDefaults,
  });

  factory Config.fromJson(dynamic json) {
    Map<String, String> parseMap(Map map) {
      return map?.cast<String, String>() ?? {};
    }

    List<String> parseArray(List list) {
      return list?.cast<String>() ?? [];
    }

    return Config(
      nameMap: parseMap(json['nameMap'] as Map),
      skipLanguages: parseArray(json['skipLanguages'] as List),
      format: exportFormatFromJson(json['exportFormat'] as String),
      outputPath: json['outputPath'] as String,
      id: json['id'] as String,
      skipCache: json['skipCache'] as bool ?? false,
      snakeCaseToCamelCase: json['snakeCaseToCamelCase'] as bool ?? false,
      headerRows: json['headerRows'] as int ?? 2,
      headerColumns: json['headerColumns'] as int ?? 2,
      sheets: parseArray(json['sheets'] as List),
      languageForDefaults: json['languageForDefaults'] as String,
    );
  }

  factory Config.fromCurrentDirectory() {
    final file = File('localizations.json');

    dynamic object;

    if (file.existsSync()) {
      final jsonString = file.readAsStringSync();
      object = json.decode(jsonString);
    } else {
      final pubspec = File('pubspec.yaml');
      final pubspecString = pubspec.readAsStringSync();
      final pubspecYaml = loadYaml(pubspecString) as YamlMap;
      object = pubspecYaml['localization_sheets'];
    }

    return Config.fromJson(object);
  }
}

void validatePlaceholders(LocalizationsTable table, Config config) {
  int countPlaceholders(String value) {
    return RegExp('%.').allMatches(value).length;
  }

  for (var key in table.keys) {
    final entries = table.languages
        .where((lang) => !config.skipLanguages.contains(lang))
        .map((lang) => MapEntry(lang, table.getString(lang, key)))
        .toList();

    final expected = countPlaceholders(table.getString('en', key));

    for (var entry in entries) {
      if (entry.value == null) {
        print('Missing value for $key.${entry.key}');
        continue;
      }

      final got = countPlaceholders(entry.value);
      if (got != expected) {
        print('placeholder error: $got/$expected, $key.${entry.key}');
      }
    }
  }
}

void saveStrings(SpreadsheetDecoder data, Config config) {
  final tables = buildMap(data);
  //deleteOut();

  for (var table in tables) {
    validatePlaceholders(table, config);

    for (var language in table.languages) {
      final name = table.name;
      final file =
          File('${currentConfig.outputPath}/$language.lproj/$name.strings');

      if (config.skipLanguages.contains(language)) {
        if (file.existsSync()) {
          file.delete();
        }
        continue;
      }

      file.createSync(recursive: true);

      final buffer = StringBuffer();

      for (var key in table.keys) {
        var value = table.getString(language, key);

        if (value == null) {
          continue;
        }
        value = value.replaceAll('"', '\\"');
        value = value.replaceAll('\\n\n', '\n');
        value = value.replaceAll('\n', '\\n');
        value = value.replaceAll('\n', '\\n');
        value = value.replaceAll('\\\\', '\\');
        buffer.writeln('"$key" = "$value";');
      }

      file.writeAsStringSync(buffer.toString());
    }
  }
}

Config currentConfig;

Future<void> run(Config config) async {
  currentConfig = config;
  final sheet = await loadSpreadSheet(config.id);

  switch (config.format) {
    case ExportFormat.arb:
      print('Generating arb files...');
      saveArb(sheet);
      break;
    case ExportFormat.strings:
      print('Generating iOS strings...');
      saveStrings(sheet, config);
      break;
    case ExportFormat.android:
      assert(false);
      break;
  }

  print('Generated.');
}

void prompt(String url) {
  print('Please go to the following URL and grant access:');
  print("  => $url");
  print("");
}

List<String> getKeys(Iterable<String> keys) {
  final r = keys.toList().reversed.toList();
  return r;
}

class LocalizationsTable {
  final String name;
  final Map<String, SplayTreeMap<String, String>> _map;

  Iterable<String> get languages => _map.keys;

  LocalizationsTable(this.name, this._map) : keys = _getKeys(_map);

  static List<String> _getKeys(Map<String, Map<String, String>> map) {
    final english = map['en'];
    if (english == null) {
      return [];
    }

    final result = english.keys.toList()..sort(customCompare);
    return result;
  }

  final List<String> keys;

  Map<String, String> mapForSerialization(String language) => _map[language];

  String getString(String language, String key, {bool provideFallback = true}) {
    final result = _map[language][key];
    if (result != null) {
      return result;
    } else if (provideFallback) {
      return _map['en'][key] ?? '';
    } else {
      return null;
    }
  }
}

/// compareAsciiLowerCase, but _ is before .
int customCompare(String lhs, String rhs) {
  return compareAsciiLowerCase(
      lhs.replaceAll('_', '-'), rhs.replaceAll('_', '-'));
}
