import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:googleapis/drive/v3.dart' as google;
import "package:googleapis_auth/auth_io.dart" as google;
import 'package:localization_sheets/storage.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:yaml/yaml.dart';

Future<google.AutoRefreshingAuthClient> obtainClient() async {
  final id = google.ClientId(
    '811930618997-macl0qns0knf1gamvlrqt8npklnajido.apps.googleusercontent.com',
    'd0Ov2Kq8Y6e3bhGWaaD60F_X',
  );

  final scopes = <String>['https://www.googleapis.com/auth/drive.readonly'];

  google.AccessCredentials credentials = await loadCredentials();

  if (credentials != null &&
      ListEquality().equals(scopes, credentials.scopes)) {
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
      await api.files.get(fileId, $fields: 'modifiedTime, name');

  final file = File(getHomePath() + '/' + meta.name + '.ods');

  var skipCache = currentConfig.skipCache;

  assert(() {
    //we usually want to skip cache when changing the script
    skipCache = true;
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
  );

  final bytes = Uint8List(media.length);
  int i = 0;

  await media.stream.forEach((part) {
    for (var b in part) {
      bytes[i++] = b;
    }
  });

  file.writeAsBytesSync(bytes);
  file.setLastModifiedSync(meta.modifiedTime.add(Duration(seconds: 1)));

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

final regexSnakeCaseToCamelCase = RegExp(r'\..');

String convertKey(String key) {
  if (!currentConfig.snakeCaseToCamelCase) {
    return key;
  }

  return key.replaceAllMapped(regexSnakeCaseToCamelCase, (x) {
    return x.group(0)[1].toUpperCase();
  });
}

Iterable<LocalizationsTable> buildMap(SpreadsheetDecoder data) sync* {
  const startColumn = 2;
  const startRow = 2;
  const keyColumn = 0;
  for (var name in data.tables.keys) {
    final table = data.tables[name];
    final header = table.rows[0];

    Map<String, Map<String, String>> map = {};

    for (int column = startColumn; column < table.maxCols; column++) {
      final h = header[column].toString().trim();
      if (isLanguageSpecifier(h)) {
        map[h] = {};
      }
    }

    for (int row = startRow; row < table.maxRows; row++) {
      final rowData = table.rows[row];
      final String key = rowData[keyColumn];

      for (int column = startColumn; column < table.maxCols; column++) {
        final String language = header[column];
        final String value = rowData[column];

        final langMap = map[language];
        if (langMap != null &&
            key != null &&
            key.isNotEmpty &&
            value != '!not relevant!') {
          langMap[convertKey(key)] = value;
        }
      }
    }

    yield LocalizationsTable(name, map);
  }
}

void saveArb(SpreadsheetDecoder data) {
  final tables = buildMap(data);
  //deleteOut();

  for (var table in tables) {
    for (var language in table.languages) {
      final file = File(currentConfig.outputPath +
          '/' +
          table.name +
          '/' +
          language +
          '.arb');
      file.createSync(recursive: true);
      final Map<String, String> langMap = table.map[language];
      final encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(langMap);
      file.writeAsStringSync(jsonString);
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

  Config(
      {@required this.nameMap,
      @required this.skipLanguages,
      @required this.format,
      @required this.outputPath,
      @required this.id,
      this.skipCache,
      this.snakeCaseToCamelCase});

  factory Config.fromJson(dynamic json) {
    Map<String, String> parseMap(Map map) {
      return map?.cast<String, String>() ?? {};
    }

    List<String> parseArray(List list) {
      return list?.cast<String>() ?? [];
    }

    return Config(
      nameMap: parseMap(json['nameMap']),
      skipLanguages: parseArray(json['skipLanguages']),
      format: exportFormatFromJson(json['exportFormat']),
      outputPath: json['outputPath'],
      id: json['id'],
      skipCache: json['skipCache'] ?? false,
      snakeCaseToCamelCase: json['snakeCaseToCamelCase'] ?? false,
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

void saveStrings(SpreadsheetDecoder data, Config config) {
  final tables = buildMap(data);
  //deleteOut();

  for (var table in tables) {
    for (var language in table.languages) {
      var name = table.name;

      if (config.nameMap.containsKey(name)) {
        name = config.nameMap[name];
        if (name == '') {
          continue;
        }
      }

      final file =
          File(currentConfig.outputPath + '/$language.lproj/${name}.strings');

      if (config.skipLanguages.contains(language)) {
        if (file.existsSync()) {
          file.delete();
        }
        continue;
      }

      file.createSync(recursive: true);
      final Map<String, String> langMap = table.map[language];

      var buffer = StringBuffer();

      for (var key in table.keys) {
        var value = langMap[key];

        if (value == null) {
          continue;
        }
        value = value.replaceAll('"', '\\"');
        value = value.replaceAll('\n', '\\n');
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
  print("Please go to the following URL and grant access:");
  print("  => $url");
  print("");
}

List<String> getKeys(Iterable<String> keys) {
  final r = keys.toList().reversed.toList();
  return r;
}

class LocalizationsTable {
  final String name;
  final Map<String, Map<String, String>> map;

  Iterable<String> get languages => map.keys;

  LocalizationsTable(this.name, this.map) : keys = _getKeys(map);

  static List<String> _getKeys(Map<String, Map<String, String>> map) {
    final english = map['en'];
    if (english == null) {
      return [];
    }

    final result = english.keys.toList()..sort(compareAsciiLowerCase);
    return result;
  }

  final List<String> keys;
}
