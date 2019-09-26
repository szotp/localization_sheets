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

  if (file.existsSync() && file.lastModifiedSync().isAfter(meta.modifiedTime)) {
    final bytes = file.readAsBytesSync();
    return SpreadsheetDecoder.decodeBytes(bytes);
  }

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

Iterable<LocalizationsTable> buildMap(SpreadsheetDecoder data) sync* {
  const startColumn = 2;
  const startRow = 2;
  const keyColumn = 0;
  for (var name in data.tables.keys) {
    final table = data.tables[name];
    final header = table.rows[0];

    Map<String, Map<String, String>> map = {};

    for (int column = startColumn; column < table.maxCols; column++) {
      final h = header[column];
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
        if (langMap != null && key != null && key.isNotEmpty) {
          langMap[key] = value;
        }
      }
    }

    yield LocalizationsTable(name, map);
  }
}

void saveArb(SpreadsheetDecoder data) {
  final tables = buildMap(data);

  final fileOut = File('out');
  if (fileOut.existsSync()) {
    File('out').deleteSync(recursive: true);
  }

  for (var table in tables) {
    for (var key in table.map.keys) {
      final file = File('out/' + table.name + '/' + key + '.arb');
      file.createSync(recursive: true);
      final Map<String, String> langMap = table.map[key];
      final encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(langMap);
      file.writeAsStringSync(jsonString);
    }
  }
}

void deleteOut() {
  final fileOut = Directory('out');
  if (fileOut.existsSync()) {
    File('out').deleteSync(recursive: true);
  }
}

enum ExportFormat { arb, strings }

class Config {
  final Map<String, String> nameMap;
  final List<String> skipLanguages;
  final ExportFormat format;
  final String outputPath;
  final String id;

  Config({
    @required this.nameMap,
    @required this.skipLanguages,
    @required this.format,
    @required this.outputPath,
    @required this.id,
  });
}

void saveStrings(SpreadsheetDecoder data, Config config) {
  final tables = buildMap(data);
  deleteOut();

  for (var table in tables) {
    for (var key in table.map.keys) {
      var name = table.name;

      if (config.nameMap.containsKey(name)) {
        name = config.nameMap[name];
        if (name == '') {
          continue;
        }
      }

      final file = File('out/$key.lproj/${name}.strings');
      file.createSync(recursive: true);
      final Map<String, String> langMap = table.map[key];

      var buffer = StringBuffer();

      langMap.forEach((key, value) {
        if (value == null) {
          return;
        }
        value = value.replaceAll('"', '\\"');
        value = value.replaceAll('\n', '\\n');
        buffer.writeln('"$key" = "$value";');
      });

      file.writeAsStringSync(buffer.toString());
    }
  }
}

Future<void> run(Config config) async {
  final sheet = await loadSpreadSheet(config.id);

  switch (config.format) {
    case ExportFormat.arb:
      saveArb(sheet);
      break;
    case ExportFormat.strings:
      saveStrings(sheet, config);
      break;
  }
}

Future<void> main(List<String> arguments) async {
  final config = Config(
    id: '14AgoSbS8GVUAXz7Pg9IVxyMSm9wEBngHnPL74NjAI2c',
    outputPath: 'out',
    skipLanguages: ['en-us'],
    nameMap: {
      'Translations': 'Localizable',
      'Configuration': '',
      'Debug': '',
    },
    format: ExportFormat.strings,
  );

  await run(config);

  exit(0);
}

void prompt(String url) {
  print("Please go to the following URL and grant access:");
  print("  => $url");
  print("");
}

class LocalizationsTable {
  final String name;
  final Map<String, Map<String, String>> map;

  LocalizationsTable(this.name, this.map);
}
