import 'package:googleapis_auth/auth_io.dart';

import 'package:localization_sheets/storage.dart';
import 'package:test/test.dart';

final _data =
    AccessCredentials(AccessToken('x', 'x', DateTime.utc(2018)), 'x', ['x']);

void main() {
  test('save', () {
    saveCredentials(_data);
  });

  test('load', () {
    saveCredentials(_data);
    final credentials = loadCredentials();
    expect(credentials.accessToken.data, _data.accessToken.data);
  });
}
