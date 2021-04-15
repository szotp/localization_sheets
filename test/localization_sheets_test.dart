import 'package:googleapis_auth/auth_io.dart';

import 'package:localization_sheets/storage.dart';
import 'package:test/test.dart';

final _data = AccessCredentials(AccessToken('x', 'x', DateTime.utc(2018)), 'x', ['x']);

void main() {
  test('save credentials', () {
    saveCredentials(_data);
  });

  test('load credentials', () {
    saveCredentials(_data);
    final credentials = loadCredentials()!;
    expect(credentials.accessToken.data, _data.accessToken.data);
  });
}
