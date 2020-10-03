import 'package:arb/models/arb_project.dart';

void insertDescriptions(ArbProject project) {
  final docs = project.documents.toList();
  docs.removeWhere((x) => x.locale == project.defaultTemplate);
  docs.insert(0, project.mapDocuments[project.defaultTemplate]);

  final def = docs.first;

  for (final entry in def.resources.values) {
    final comments = <String>[];

    comments.add('/// ### ${entry?.value?.text}');

    for (final doc in docs) {
      final resource = doc.resources.values
          .firstWhere((x) => x.id == entry.id, orElse: () => null);
      var value = resource?.value?.text;
      value ??= '!!! MISSING !!!';
      comments.add('/// - ${doc.locale}: $value');
    }

    final commentsString = comments.join('\n');

    entry.description = '\n$commentsString';
  }
}
