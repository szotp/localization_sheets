#!/usr/bin/env dart

import 'dart:io';
import 'package:localization_sheets/localization_sheets.dart';

Future<void> main(List<String> arguments) async {
  final config = Config.fromCurrentDirectory();
  await run(config);
  exit(0);
}
