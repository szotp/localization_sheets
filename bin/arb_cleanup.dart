#!/usr/bin/env dart

import 'dart:io';
import 'package:arb/models/arb_project.dart';
import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';
import 'package:args/args.dart';

import 'package:localization_sheets/strings_to_arb.dart';

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
    final directory = Directory('assets/languages');

    ArbProject project;

    if (importIosStrings != null) {
      project = parseStrings(importIosStrings);
    } else {
      project = loadProject(directory: directory);
    }

    insertDescriptions(project);
    saveProject(project, directory);
  }
}

Future<void> main(List<String> arguments) async {
  ArbCleanupCommand()
    ..parse(arguments)
    ..execute();
}
