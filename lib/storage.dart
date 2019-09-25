import 'dart:convert';
import 'dart:io';
import "package:googleapis_auth/auth_io.dart" as google;

String getHomePath() {
  String home = "";
  Map<String, String> envVars = Platform.environment;
  if (Platform.isMacOS) {
    home = envVars['HOME'];
  } else if (Platform.isLinux) {
    home = envVars['HOME'];
  } else if (Platform.isWindows) {
    home = envVars['UserProfile'];
  }

  return home + '/.localization_sheets';
}

File _getTokenFile() {
  final x = getHomePath() + "/token.json";
  return File(x);
}

void saveCredentials(google.AccessCredentials credentials) {
  final jsonObject = {
    'scopes': credentials.scopes,
    'accessToken.data': credentials.accessToken.data,
    'accessToken.expiry': credentials.accessToken.expiry.toIso8601String(),
    'accessToken.type': credentials.accessToken.type,
    'refreshToken': credentials.refreshToken,
    'idToken': credentials.idToken,
  };

  final file = _getTokenFile();
  file.createSync(recursive: true);
  file.writeAsStringSync(json.encode(jsonObject));
}

google.AccessCredentials loadCredentials() {
  final file = _getTokenFile();
  if (!file.existsSync()) {
    return null;
  }

  final jsonString = file.readAsStringSync();
  final js = json.decode(jsonString);

  final token = google.AccessToken(
    js['accessToken.type'],
    js['accessToken.data'],
    DateTime.parse(js['accessToken.expiry']),
  );

  return google.AccessCredentials(
    token,
    js['refreshToken'],
    List<String>.from(js['scopes']),
    idToken: js['idToken'],
  );
}
