import 'dart:io';
import 'package:localization_sheets/arb.dart';
import 'package:localization_sheets/insert_descriptions.dart';

Future<void> main(List<String> arguments) async {
  Directory.current = 'assets/languages';
  final project = loadProject();
  insertDescriptions(project);
  saveProject(project, Directory.current);
}
