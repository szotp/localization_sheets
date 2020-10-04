#!/usr/bin/env dart

import 'dart:io';
import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:args/args.dart';

class ArbCleanupCommand {
  String importIosStrings;

  void parse(List<String> args) {
    ArgParser()
      ..addOption(
        "import_ios_strings",
        callback: (String value) => importIosStrings = value,
        help: 'Path pointing to Localizable.strings file that you want to convert into .arb files for this project',
      )
      ..parse(args);
  }

  void execute() {
    Directory.current = 'assets/languages';
    final project = loadProject();
    insertDescriptions(project);
    saveProject(project, Directory.current);
  }
}

Future<void> main(List<String> arguments) async {
  ArbCleanupCommand()
    ..parse(arguments)
    ..execute();
}
