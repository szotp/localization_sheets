import 'package:googleapis_auth/auth_io.dart';

import 'package:localization_sheets/storage.dart';
import 'package:test/test.dart';

final data =
    AccessCredentials(AccessToken('x', 'x', DateTime.utc(2018)), 'x', ['x']);

void main() {
  test('save', () {
    saveCredentials(data);
  });

  test('load', () {
    saveCredentials(data);
    final credentials = loadCredentials();
    expect(credentials.accessToken.data, data.accessToken.data);
  });
}
